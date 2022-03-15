function img_lut = imapplylut(img, lut, varargin)
% applies 1D or 3D LUT (color lookup table) to image
%
% From https://ww2.mathworks.cn/matlabcentral/fileexchange/...
%             43004-imlut-img-lut-kind-order-colorscheme
% Modified by guocheng@cuc.edu.cn at 3 Mar 2022
%
% Inputs:
%  Required (2):
%    img - m-by-n-by-3 RGB (BGR not supported) image array:
%          single | double (should be normalized [0,1])
%    lut - m-by-3 or m-by-1 array:
%          single | double (should be normalized [0,1])
% 
%  Optional (3):
%    type - char:
%           '1D' | '3D' (default)
%           specifying whether a 1D LUT or 3D LUT is used
%    order - char:
%            'standrad' (default) | 'inverse'
%            order of LUT entries. Examples under 'RGB' colorSchme:
%             Inverse Order         Standard Order
%                R G B                   R G B
%                0 0 0                   0 0 0
%                1 0 0                   0 0 1
%                2 0 0                   0 0 2
%                0 1 0                   0 1 0
%                1 1 0                   0 1 1
%                2 1 0                   0 1 2
%                0 2 0                   0 2 0
%                 ...                     ...
%                2 2 2                   2 2 2
%
%    colorScheme - char:
%                  channel order of LUT
%                  'RGB' (default) |'BGR' 
%
% Outputs:
%    img_lut - image after applying LUT, normalized to [0,1]
%
% Example: 
%    img = imread('path_to_image');
%    img = _normalize_(img);
%    % lut = dlmread('path_to_lut.cube', ' ', 4, 0); (???)
%    % lut = dlmread('path_to_lut.cube');
%    lut = readmatrix('path_to_lut.cube', 'FileType', 'text');
%    [img_lut] = imapplylut(img, lut);
%    imshow(img_lut)
%
% See also: dlmread(), readmatrix(), imread()

% Author: Christopher Haccius(1)
% Telecommunications Lab, Saarland University, Germany
% email: haccius@nt.uni-saarland.de
% August 2013; Last revision: 02-July-2015

p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addRequired(p,'lut',@(x)validateattributes(x,...
        {'numeric'},{'2d'}))
    addOptional(p,'type','3D',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'order','standard',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'colorScheme','RGB',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    parse(p,img,lut,varargin{:})

img = double(img);          % convert input image to double precision

[m,n,o] = size(img);        % get size of input image
img_lut = zeros(m,n,o);     % asign output image

[g,~] = size(lut);          % get length of lut

switch p.Results.order      % set order of 3D LUT cube
    case 'inverse'
        o = [2 3 1 2 3 1 2 3 1];
    case 'standard'
        o = [1 2 3 1 2 3 1 2 3];
    % 231 reordering is necessary because meshgrid() uses first
    % component in real horizontal direction whereas MATLAB matrices always
    % use first component in vertical direction
    otherwise
        disp('Warning: Only standard or inverse order is supportted!');
        disp('Original image is returned.');
        img_lut = img;  % return unchanged image
end

switch p.Results.colorScheme % set order of 3D LUT cube
    case 'RGB'
        R=1; G=2; B=3;       % to RGB color scheme
    case 'BGR'               % or
        R=3; G=2; B=1;       % to BGR color scheme
    otherwise
        disp('Warning: Only RGB or BGR color scheme is supportted!');
        disp('Original image is returned.');
        img_lut = img;  % return unchanged image
end

switch p.Results.type
    case '3D'
        d = uint8(g^(1/3));  % calculate size of color cube
        [a,b,c] = meshgrid(linspace(0,1,d));
                             % create 3D grid size of color cube     
        lutR = reshape(lut(:,1),d,d,d); 
                             % reshape red component of lut for 3D
        lutR = permute(lutR,[o(1) o(2) o(3)]);
                             % permute cube dimensions according to order
        lutG = reshape(lut(:,2),d,d,d); 
                             % respape green component of lut for 3D
        lutG = permute(lutG,[o(4) o(5) o(6)]);
                             % permute cube dimensions according to order
        lutB = reshape(lut(:,3),d,d,d); 
                             % reshape blue component of lut for 3D
        lutB = permute(lutB,[o(7) o(8) o(9)]);
                             % permute cube dimensions according to order   
        img_lut(:,:,1) = interp3(a,b,c,lutR,...
                img(:,:,R),img(:,:,G),img(:,:,B)); % interpolate red comp
        img_lut(:,:,2) = interp3(a,b,c,lutG,...
                img(:,:,R),img(:,:,G),img(:,:,B)); % interpolate green comp
        img_lut(:,:,3) = interp3(a,b,c,lutB,...
                img(:,:,R),img(:,:,G),img(:,:,B)); % interpolate blue comp

    case '1D'
        a = linspace(0,1,g);% create 1D scale size of color LUT
        img_lut(:,:,1) = interp1(a,lut(:,R),img(:,:,1));
                            % interpolate red component
        img_lut(:,:,2) = interp1(a,lut(:,G),img(:,:,2));
                            % interpolate green component
        img_lut(:,:,3) = interp1(a,lut(:,B),img(:,:,3));
                            % interpolate blue component
   
% if neither 1D nor 3D given, display warning and return input image
    otherwise
        disp('Warning: Only 1D or 3D LUT is supportted!');
        disp('Original image is returned.');
        img_lut = img;  % return unchanged image
end
