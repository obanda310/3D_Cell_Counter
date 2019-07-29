%% Choose Folder(s) With Images to Analyze
clear all
close all

answer = questdlg('Use a previous list of directories?');
if strcmp(answer,'Yes') == 1
    [listfile,listpath]=uigetfile('.mat','Choose a previous list a directories.');
    load([listpath listfile])
    skipsave = 1;
else
    skipsave = 0;
    numpath = 1;
    prompt = ('Choose an image stack with known cell count.');
    f = msgbox(prompt);
    uiwait(f)
    buildpathlist = 0;
    while buildpathlist == 0
        [name,path] = uigetfile('*.tif');
        pathlist{1,numpath} = [path name];
        pathlist{2,numpath} = path;
        pathlist{3,numpath} = name;
        numpath = numpath +1;
        answer = questdlg('Add another directory?');
        if strcmp(answer,'Yes') ~= 1
            buildpathlist = 1;
        end
    end
end

% Input the known counts
for i = 1:size(pathlist,2)
    pathlist{4,i} = input(['How many cells in the file:_' pathlist{3,i}]);
end

% Save the list
if skipsave == 0
    answer = questdlg('Save this list of directories?');
    if strcmp(answer,'Yes') == 1
        [listfile,listpath] = uiputfile('*.mat','Choose a location to save directory list');
        save([listpath listfile],'pathlist')
    end
end


%% Create Filtered Stacks
for thisFile = 1:size(pathlist,2)
    current=pathlist{3,thisFile};
    cd(pathlist{2,thisFile})
    
    files = dir('*.mat'); %Check Directory for default filenames
    try
        load([current '_FilteredStack.mat'])
    catch
    [stack,meta] = getImages(current);    
    if size(stack,1) == 2048
        tempstack = zeros(512,512,size(stack,3));
        for i = 1:size(stack,3)
            tempstack(:,:,i) = imresize(stack(:,:,i),.25);
        end
        clear stack
        stack = tempstack;
        clear tempstack
    end        
    %pixel size in microns
    xyPix = 1.3;
    zPix = 0.53;
    
    %desired cell diameter in microns
    CDlow = 14;
    CDhigh = 23;
    CDi = mean([CDlow CDhigh]);
    
    %filter size and object detection window size
    fxy = CDi/xyPix;
    fz = CDi/zPix;
    
    %Cell Volume (pixels) based on expected size
    cv = 8500;% fxy^2*fz;
    
    stack2 = imadjustn(uint8(stack));
    b=bpass3dMB(stack2, [1 1 1], [fxy fxy  fz],[0 0]);
    save(strcat(current,'_FilteredStack.mat'),'b')
    end
end
%% Calculate Optimal Volume

%First index data for each sample
for i = 1:size(pathlist,2)
clear b d e
load([pathlist{1,i} '_FilteredStack.mat'])    
d = zeros(size(b));
CO = 150;
d = b>CO;
e = bwlabeln(d);
clear stats
stats = regionprops(e,'Area','Image');
Area2{i} = cat(1,stats.Area);
end

%%Then optimize against data
cv0 = 8500;
lb = 2000;
ub = 20000;
cvest = fmincon(@(cv) countcells(pathlist,Area2,cv),cv0,[],[],[],[],lb,ub);

cv = cvest;
for i = 1:size(Area2,2)
    clear AreaT
    AreaT = Area2{i};
    AreaT(AreaT<.25*cv) = 0;
    AreaT(AreaT<cv & AreaT>.25*cv) = cv;
    Area3 = (AreaT/cv); %round
    NumCells(i) = sum(Area3);
    lsqi(i) = (NumCells(i) - pathlist{4,i})^2;
end
    lsq = sqrt(sum(lsqi));

save([listpath 'CellVolumeEstimate.mat'], 'cv','NumCells','pathlist')
cd(listpath)

function lsq = countcells(pathlist,Area2,cv)
for i = 1:size(Area2,2)
    clear AreaT
    AreaT = Area2{i};
    AreaT(AreaT<.25*cv) = 0;
    AreaT(AreaT<cv & AreaT>.25*cv) = cv;
    Area3 = (AreaT/cv); %round
    NumCells(i) = sum(Area3);
    lsqi(i) = (NumCells(i) - pathlist{4,i})^2;
end
    lsq = sqrt(sum(lsqi));
end