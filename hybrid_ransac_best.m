%function main_hybrid(ID) vv
addpath(genpath('.'));
load('./Metadata/SUNRGBDMeta_best_Oct19.mat');
inputFolder = '/volumes/sunhome/Yinda_2303/';

inputFolderDir = dir([inputFolder,'input']);
inputCateList = {};
for i = 1:length(inputFolderDir)
    inputCateList{end+1} = inputFolderDir(i).name;
end

for imageId = 1:100

disp(imageId);

folderPath = ['./results/scene',num2str(imageId)];
createFolderInstr = ['mkdir ',folderPath];
system(createFolderInstr);

%specify scene to recreate:
imageData = SUNRGBDMeta_best_Oct19(imageId);

%readData:
objDataset = imageData.groundtruth3DBB;

[all_obj_points, all_obj_dim, XYZ, inside_bb] = get_obj_points(SUNRGBDMeta_best_Oct19,imageId,inputCateList);
[rgb,points3d,depthInpaint,imsize,XYZ]=read3dPoints(imageData);

points3dvalid = points3d;

points3dvalid(isnan(points3d(:,1)) | inside_bb, 1) = 0;
points3dvalid(isnan(points3d(:,1)) | inside_bb, 2) = 0;
points3dvalid(isnan(points3d(:,1)) | inside_bb, 3) = 0;

Xvalid = points3dvalid(:,1);
Yvalid = points3dvalid(:,2);
Zvalid = points3dvalid(:,3);

XvalidMatrix = reshape(Xvalid, imsize);
YvalidMatrix = reshape(Yvalid, imsize);
ZvalidMatrix = reshape(Zvalid, imsize);

XYZvalid = cat(3,XvalidMatrix,YvalidMatrix,ZvalidMatrix);

[points, faces] = point2mesh(double(XYZvalid));

points = points';
faces = faces';

points(points(:,1) == 0,:) = [];
faces(faces(:,1) == 0,:) = [];


pickList = [];
for i = 1:length(objDataset)
    pickList = [pickList,1];
end

%get paths:
outputPath = ['./output/scene',num2str(imageId)];
all_list = [];
for o=1:length(objDataset)
    temp = dir([outputPath,'/',num2str(o),'_',objDataset(o).classname,'_list.txt']);
    all_list = [all_list;temp];
end

bestModelPath = [];

for i = 1:length(all_list)
    fname = all_list(i).name;
    fpath = [outputPath,'/',fname];
    fid = fopen(fpath,'r');
    file_text=fread(fid, inf, 'uint8=>char')';
    fclose(fid);
    file_lines = regexp(file_text, '\n+', 'split');
    line1 = file_lines{pickList(i)};
    line1list = strsplit(line1);
    bestPath = line1list(1);
    bestModelPath=[bestModelPath;bestPath];
end

allV = points;
allF = faces;

totalPrevV = length(allV);
%create objects:
for i = 1:length(objDataset)
    objId = i;
    objData = objDataset(objId);
    keyword = objData.classname;
    
    bestPath = bestModelPath(i);
    bestPath = bestPath{1};
    
    %same obj use same list of models:
    objname = keyword;
    for objid = 1:length(objDataset)
        if strcmp(objname,objDataset(objid).classname)
            bestPath = bestModelPath(objid);
            bestPath = bestPath{1};
            break;
        end
    end
    
    
    if strcmp(bestPath,'')
        continue;
    end
    
    [vList,fList] = create_obj(objData, [inputFolder,bestPath]);
    
    allV = [allV;vList];
    fList = fList + totalPrevV;
    allF = [allF;fList];
    totalPrevV = totalPrevV + size(vList,1);
end

% write_img([folderPath,'/scene',num2str(imageId),'.jpeg'],allV,allF,imageData);
% write_ply([folderPath,'/scene',num2str(imageId),'.ply'],allV,allF,imageData);

roomDepth = get_wall_depth(imageData);
hybridDepth = render_depth(allV, allF, imageData);

[roomrgb,roomPoints3dall, roomXYZ] = read_3d_pts_general(roomDepth,imageData.K,size(roomDepth),imageData.rgbpath);
wall_inside_bb = check_inside_bb(imageData,roomPoints3dall);
wall_inside_bb_matrix = reshape(wall_inside_bb, imsize);


%only consider wall points inside bb:
roomDepth(~wall_inside_bb_matrix & depthInpaint == 0) = 0;
hybridDepth(hybridDepth == 0) = roomDepth(hybridDepth == 0);
depthMin = min(hybridDepth(:));
depthMax = max(hybridDepth(:));
depthNorm = double(hybridDepth-depthMin)/double(depthMax-depthMin);
depthNorm (depthNorm == 0) = flintmax;
[rgb,points3dall, XYZ]=read_3d_pts_general(hybridDepth,imageData.K,size(hybridDepth),imageData.rgbpath);
points3dall = (imageData.Rtilt*points3dall')';
points2ply([folderPath,'/scene',num2str(imageId),'_bb.ply'], points3dall');
imwrite(depthNorm, [folderPath,'/scene',num2str(imageId),'_bb.jpeg']);

end