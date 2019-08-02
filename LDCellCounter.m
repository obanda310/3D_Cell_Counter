%% Count Cells in Many Directories
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
    prompt = ('Choose a folder with .tif files to analyze');
    f = msgbox(prompt);
    uiwait(f)
    buildpathlist = 0;
    while buildpathlist == 0
        dirlist{numpath} = uigetdir;
        numpath = numpath +1;
        answer = questdlg('Add another directory?');
        if strcmp(answer,'Yes') ~= 1
            buildpathlist = 1;
        end
    end
end

if skipsave == 0
    answer = questdlg('Save this list of directories?');
    if strcmp(answer,'Yes') == 1
        [listfile,listpath] = uiputfile('*.mat','Choose a location to save directory list');
        save([listpath listfile],'dirlist')
    end
end

%% Load Volume Estimate (from Volume Optimizer)
[VolName VolPath] = uigetfile('*.mat','Please locate the volume estimate from the optimization script');
load([VolPath VolName])
%% Count Cells in Every .tif in Each Directory
tic
itemNo = 1;
for thisPath = 1:size(dirlist,2)    
    currentpath = dirlist{thisPath};
    cd(currentpath)
    files = dir('*.tif'); %Check Directory for default filenames
    if size(files,1) ==0
        disp('There are no tifs in this folder')
    end
    for thisFile = 1:length(files)
        try
        current=files(thisFile).name;
        
        %Scale and Process Input Image Stack
        try
            load([current '_FilteredStack.mat'])
        catch
            [b,meta] = formatImages(current);
            save(strcat(current,'_FilteredStack.mat'),'b')            
        end
        %ShowStack(b)
        
        d = zeros(size(b));
        CO = 150;
        d = b>CO;
        e = bwlabeln(d);
        clear stats
        stats = regionprops(e,'Area','Image');
        clear Area2
        Area2 = cat(1,stats.Area);
        
        Area2(Area2<.25*cv) = 0;
        Area2(Area2<cv & Area2>.25*cv) = cv;
        
        Area3 = round(Area2/cv);
        NumCellsB = sum(Area3); 
        
     
        %%
        %                         r = feature3dMB(b, [fxy fxy fz] , [fxy fxy fz], [size(stack,1) size(stack,2) size(stack,3)],[1 1 1],[fxy fxy fz],100000,.05);
        %                         NumCellsA = size(r,1);
        %                         toc
        save(strcat(current,'_Stats.mat'),'NumCellsB')
        disp(['Counted ' num2str(NumCellsB) ' in ' current ' (at ' num2str(toc) ' seconds)'])
        
        
        cellcounts{itemNo,1} = strcat(dirlist(1,thisPath),'\',current);
        cellcounts{itemNo,2} = NumCellsB;
        catch
            disp([current ' failed. We should tell Omar about this! Or maybe a dependency is missing...'])
        end
        itemNo = itemNo +1;
        
    end    
end
cd(listpath)
save('FinalCounts.mat','cellcounts')