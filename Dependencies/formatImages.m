% Image Processing Instructions for Cell Counter Program
function [processedImage,meta] = formatImages(filename)
current = filename;

[stack,meta] = getImages(current);

prevScaleX = meta.sizeX/meta.OrigSizeX;
prevScaleY = meta.sizeY/meta.OrigSizeY;

%Remove excess Z slices
if meta.scalingZ*1000000 < 3
    reScaleZ = round(3/(meta.scalingZ*1000000));
    removeSlices = [1:1:size(stack,3)]';
    removeSlices([1:reScaleZ:size(stack,3)]',:) = [];
    stack(:,:,removeSlices) = [];
else
    reScaleZ = 1;
end

%Resize the image stack to 512x512
if size(stack,1) ~= 512
    reScaleX = 512/meta.sizeX;
    reScaleY = 512/meta.sizeY;
    tempstack = zeros(512,512,size(stack,3));
    for i = 1:size(stack,3)
        tempstack(:,:,i) = imresize(stack(:,:,i),reScaleX);
    end
    clear stack
    stack = tempstack;
    clear tempstack
else
    reScaleX = 1;
    reScaleY = 1;
end

%Calculate final pixel size in microns
xPix = (meta.scalingX*1000000)/prevScaleX/reScaleX;
meta.finalScalingX = xPix;
yPix = (meta.scalingY*1000000)/prevScaleY/reScaleY;
meta.finalScalingY = yPix;
zPix = (meta.scalingZ*1000000)*reScaleZ;
meta.finalScalingZ = zPix;

%Approximate cell diameter in microns (may need to be updated!!!)
CDlow = 14;
CDhigh = 23;
CDi = mean([CDlow CDhigh]);

%filter size and object detection window size
fx = CDi/xPix;
fy = CDi/yPix;
fz = CDi/zPix;

stack2 = imadjustn(uint8(stack));
processedImage=bpass3dMB(stack2, [1 1 1], [fx fy fz],[0 0]);

