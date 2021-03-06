
clearvars,
close all,
clc,

%addpath('./test/');

images_ = 27:28;
images = cell(numel(images_), 1);

showSURFfeatures = 0;
showRANSACinliers = 0;
loadPfromfile = 0;

for i=1:numel(images_)
    images{i} = imrotate(rgb2gray(imread(strcat('./temple/temple', num2str(images_(i),'%04d'),'.png'))), 90);
end

matchedPoints = surfFeatures(images);

if showSURFfeatures
    for i=1:numel(images)-1
        figure(1);ax = axes; 
        showMatchedFeatures(images{i},images{i+1},matchedPoints{i}{1},matchedPoints{i}{2},'montage','Parent', ax);
        pause(0.1);
    end
    pause(0.8);
   % close all
end

F = {numel(matchedPoints)};
inliers = {numel(matchedPoints)};

for i = 1:numel(matchedPoints)
    try
        image1Coords = matchedPoints{i}{1}.Location';
        image2Coords = matchedPoints{i}{2}.Location';
        [F{i}, inliers{i}] = ransacfitfundmatrix7(image1Coords, image2Coords, 0.01);
    catch
        warning('Failed to generate the fundamental matrix');
    end
end

if showRANSACinliers
    for i=1:numel(matchedPoints)
        RANSACinliers1 = matchedPoints{i}{1}.Location;RANSACinliers1 = RANSACinliers1(inliers{i},:);
        RANSACinliers2 = matchedPoints{i}{2}.Location;RANSACinliers2 = RANSACinliers2(inliers{i},:);
        figure(2);ax = axes; 
        showMatchedFeatures(images{i},images{i+1},RANSACinliers1, RANSACinliers2,'montage','Parent', ax);
        pause(0.1);
    end
    pause(0)
  %  close all
end

%%%%%%% INTRINSIC CAMERA PARAMETERS (K)
K = [1520.400000 0.000000    302.320000 
     0.000000    1525.900000 246.870000 
     0.000000    0.000000    1.000000];

P_ = cell(numel(F)+1,1);
P = cell(numel(F)+1,1);
R = cell(numel(F)+1,1);
points3d = cell(numel(F), 1); 
 
if loadPfromfile == 0
    %Essential matrixes
    E = {numel(matchedPoints)};

    for i=1:numel(matchedPoints)
       E{i} = transpose(K) * F{i} * K; 
    end

    P{1} = K*eye(3,4);  %all the cameras will be relative to de origin
    [U,S,V] = svd(E{i});
    T = U*[0,1,0;-1,0,0;0,0,0]*transpose(U);
    R{1} = U*transpose([0,1,0;-1,0,0;0,0,1])*transpose(V);
    t = zeros(3,1);

    for i=1:numel(E)
        [U,S,V] = svd(E{i});
        T = U*[0,1,0;-1,0,0;0,0,0]*transpose(U);
        R{i+1} = U*transpose([0,1,0;-1,0,0;0,0,1])*transpose(V);
        t = null(T);
        P{i+1} = K*[R{i+1} t];
    end
else
    M = dlmread('temple/temple_par.txt', ' ');

    for i=1:numel(images_)
        P_{i} = [[M(i,10:12);M(i,13:15);M(i,16:18)],M(i,19:21)'];
    end

    for i=1:numel(images_)
        P{i} = K * P_{i};
    end
end

for i=1:numel(F)

    RANSACinliers1 = matchedPoints{i}{1}.Location;RANSACinliers1 = RANSACinliers1(inliers{i},:);
    RANSACinliers2 = matchedPoints{i}{2}.Location;RANSACinliers2 = RANSACinliers2(inliers{i},:);
    imsize = [size(images{1},1), size(images{1},2)];
    points3d{i} = [];
    for j=1:size(RANSACinliers1, 1)
        X = vgg_X_from_xP_nonlin([RANSACinliers1(j,:)', RANSACinliers2(j,:)'],{P{i},P{i+1}},[imsize; imsize]);
        X = X./X(4);
        points3d{i} = [points3d{i}; X(1:3)'];
    end
end

figure(6),

hold on
for i=1:numel(F)        %24-25 works pretty well -- 14-15 is also p good
    if size(points3d{i}) > 0
    pcshow(points3d{i}, 'VerticalAxis', 'y', 'VerticalAxisDir', 'down', ...
        'MarkerSize', 120);
    end
    colormap winter
end

% 
% for i=1:numel(P)
%     cam = plotCamera('Location', P_{i}(:,4), 'Orientation', P_{i}(1:3, 1:3),'Opacity',0,'Size',0.001); 
%     text(double(P_{i}(1,4)), double(P_{i}(2,4)), double(P_{i}(3,4)), num2str(i+1));
%     drawnow();
% end
% %hold off
if loadPfromfile
    axis([-.1 .1 -.05 .2 -.1 .1]) 
end