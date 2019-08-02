%% Approximate Cell Volume Value for Cell Counting
clear all
close all

%% Adds relevant functions to path
% Works as long as folders have not been moved around
tempPath = cd;
funcName = length(mfilename);
funcPath = mfilename('fullpath');
funcPath = funcPath(1:end-funcName);
cd(funcPath)
addpath(genpath([funcPath 'Dependencies']));
cd(tempPath)
%% Load, Create, and Save Lists
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
    
    %Scale and Process Input Image Stack
    try
        load([current '_FilteredStack.mat'])
    catch
        [b,meta] = formatImages(current);
        save(strcat(current,'_FilteredStack.mat'),'b')
    end
end
%% Calculate Optimal Volume

%First index data for each sample
for i = 1:size(pathlist,2)
    clear b d e
    load([pathlist{1,i} '_FilteredStack.mat'])
    % Normalize values in processed stack
    scaleB = 255/max(b(:));
    c = imadjustn(uint8(round(b*scaleB)));    
    d = zeros(size(b));
    CO = 100;
    d = c>CO;
    e = bwlabeln(d);
    clear stats
    stats = regionprops(e,'Area','Image');
    Area2{i} = cat(1,stats.Area);
end

%%Then optimize against data
cv0 = 1417;
lb = 1;
ub = 3333;
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