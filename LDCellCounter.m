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

[VolName VolPath] = uigetfile('*.mat','Please locate the volume estimate from the optimization script');
load([VolPath VolName])
%%
for thisPath = 1:size(dirlist,2)
    tic
    currentpath = dirlist{thisPath};
    cd(currentpath)
    files = dir('*.tif'); %Check Directory for default filenames
    if size(files,1) ==0
        disp('There are no tifs in this folder')
    end
    %%
    for thisFile = 1:length(files)
        
                current=files(thisFile).name;
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
                
                stack2 = imadjustn(uint8(stack));
                b=bpass3dMB(stack2, [1 1 1], [fxy fxy  fz],[0 0]);
                save(strcat(current,'_FilteredStack.mat'),'b')
             end
                %ShowStack(b)
                toc
                %%
%                         r = feature3dMB(b, [fxy fxy fz] , [fxy fxy fz], [size(stack,1) size(stack,2) size(stack,3)],[1 1 1],[fxy fxy fz],100000,.05);
%                         NumCellsA = size(r,1);
%                         toc
                %%
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
                
                figure
                hist(Area2,100)
                Area3 = round(Area2/cv);
                NumCellsB = sum(Area3)
                toc
                %%
                save(strcat(current,'_Stats.mat'),'NumCellsB')
                toc
                          

    end
end
