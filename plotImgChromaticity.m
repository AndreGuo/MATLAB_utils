function [] = plotImgChromaticity(img, bit_depth, gamut, varargin)
    % Copyright: guocheng@cuc.edu.cn, 24 Nov 2021
    %
    % Input argsuments:
    %  Required (3):
    %  'img'          - m-by-n-by-3 RGB (BGR not supported) image array:
    %                   uint8 (8bit) | uint16 (10/12/16bit) |
    %                   single or double (from hdrread() or exrread())
    %  'bit_depth'    - num:
    %                   8 (common image file in uint8) |
    %                   10 (10bit TV exhancge in uint16) |
    %                   12 (12bit TV exhancge in uint16) |
    %                   16 (16bit .png/.tif/etc. in uint16) |
    %                   1 (for normalized 32bit float-point .hdr/.exr file)
    %  'gamut'        - char:
    %                   'adobergb' | 'srgb' | 'bt709' (same as 'srgb') |
    %                   'bt2020' (default PQ unlinear, see 'wcg_oetf') |
    %                   'other' (param 'matrix' required in this case)
    %  Optional (5):
    %  'scale_factor' - num:
    %                   1 (default) |
    %                   (0,1) (downscale image for faster compute)
    %  'limit_range'  - bool:
    %                   false (default) |
    %                   true (for image from some TV exhancge)
    %  'matrix'       - 3-by-3 vetor:
    %                   require when 'gamut' is 'other',
    %  find more at: brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
    %                   below show examples under D65 reference-white:
    %                   [0.4866 0.2657 0.1982;...
    %                    0.2290 0.6917 0.0793;...
    %                    0.0000 0.0451 1.0439];
    %                   (DCI-P3, dispaly gamut) |
    %
    %                   [0.430 0.342 0.178;...
    %                    0.222 0.707 0.071;...
    %                    0.020 0.130 0.939];
    %                   (EBU-PAL, dispaly gamut) |
    %
    %                   [0.6071 0.1736 0.1995;...
    %                    0.2990 0.5870 0.1140;...
    %                    0.0000 0.0661 1.1115];
    %                   (BT.601/NTSC(C reference-white), dispaly gamut) |
    %
    %                   [0.638008 0.214704 0.097744;...
    %                    0.291954 0.823841 -0.115795;...
    %                    0.002798 -0.067034 1.1153294];
    %                   (Arri Alexa Wide Gamut, camera gamut) |
    %
    %                   [0.4024 0.4610 0.0871;...
    %                    0.1904 0.7646 0.0450;...
    %                    −0.0249 0.1264 0.9873];
    %                   (Fairchild HDR Dataset Dikon D2x, camera gamut) |
    %  'wcg_oetf'     - char:
    %                   works only when {'gamut', 'bt2020'}
    %                   'PQ' (default) | 'HLG' | 'gamma'
    %  'linearize'    - function handle:
    %                   require when {'gamut', 'other'} & non-linear linput
    %                   @(x)(x) (default, assuming input is linear) |
    %                   @(x)(x^2.2) (gamma2.2 recommended for most cases)
    %
    % Plot window can be saved using e.g.:
    %  exportgraphics(gca, 'name.png','Resolution', 300);
    %
    % Note:
    %  1. This fuction assumes a D65 white-point;
    % 
    %  2. {'gamut', 'bt2020'} require MATLAB version >= R2020b.
    %     If not, you can use {'gamut', 'other'} with {'matrix', 
    %     [0.6370 0.1446 0.1698;...
    %      0.2627 0.6780 0.0593;...
    %      0.0000 0.0281 1.0610]} and
    %     {'linearize', @(x)((max((x.^(1/m2)-c1), zeros(size(x)))./(c2...
    %     -c3.*(x.^(1/m2)))).^(1/m1));} for PQ where: m1 = 2610/16384;
    %     m2 = 2523/32; c1 = 3424/4096; c2 = 2413/128; c3 = 2392/128; or
    %     {'linearize', @(x)(((x.^2)/3).*(x>=0 & x<=1/2) +...
    %     (exp((x-c)/a)+b).*(x>1/2 & x<=1))} for HLG nonlinear where:
    %     a = 0.17883277; b = 0.02372241; c = 1.00429347;
    %
    %  3. Similar fuction is found in Python as: colour_science.plotting()

    p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addRequired(p,'bit_depth',@(x)validateattributes(x,...
        {'numeric'},{'nonempty'}))
    addRequired(p,'gamut',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'scale_factor',1,@(x)validateattributes(x,...
        {'numeric'},{'nonempty'}))
    addOptional(p,'limit_range',false,@(x)validateattributes(x,...
        {'logical'},{'nonempty'}))
    addOptional(p,'matrix',ones(3),@(x)validateattributes(x,...
        {'numeric'},{'size',[3,3]}))
    addOptional(p,'wcg_oetf','PQ',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'linearize',@(x)(x),@(x)validateattributes(x,...
        {'function_handle'},{'nonempty'}))
    parse(p,img,bit_depth,gamut,varargin{:})

    % STEP 1
    % reading in unsigned interger image, scaling for faster computation
    rgb = img;
    if (p.Results.scale_factor ~= 1)
        rgb = imresize(rgb, p.Results.scale_factor, "nearest");
    end

    % normalizing input to [0,1]
    rgb_norm = double(rgb)/(2^bit_depth);
    
    if strcmp(gamut,'srgb') == true
        gamut = 'bt709';
    end

    % STEP 2
    % calculating XYZ tri-stimulus of image
    switch gamut
        case 'bt709'
            xyz = rgb2xyz(rgb_norm);
        case 'adobergb'
            xyz = rgb2xyz(rgb_norm,'ColorSpace','adobe-rgb-1998');
        case 'bt2020'
            rgb_12b = uint16(rgb_norm*4096);
            if p.Results.limit_range == false
                full_2_limited = @(x)(0.85546875*x+256);
                rgb_12b = full_2_limited(rgb_12b);
            end
            % rgbwide2xyz (in ver. >= R2020b) is for limited-range input
            switch p.Results.wcg_oetf
                case 'PQ'
                    xyz = rgbwide2xyz(rgb_12b,12,'ColorSpace','BT.2100');
                case 'HLG'
                    xyz = rgbwide2xyz(rgb_12b,12,'ColorSpace','BT.2100',...
                        'LinearizationFcn','HLG');
                case 'gamma'
                    xyz = rgbwide2xyz(rgb_12b,12,'ColorSpace','BT.2020');
                otherwise
                    error('Unsupported OETF for BT.2020 gamut!')
            end
        case 'other'
            un2linear = p.Results.linearize;
            rgbother2xyz = @(rgb,m)(cat(3,...
                (m(1,1)*rgb(:,:,1)+m(1,2)*rgb(:,:,2)+m(1,3)*rgb(:,:,3)),...
                (m(2,1)*rgb(:,:,1)+m(2,2)*rgb(:,:,2)+m(2,3)*rgb(:,:,3)),...
                (m(3,1)*rgb(:,:,1)+m(3,2)*rgb(:,:,2)+m(3,3)*rgb(:,:,3))));
            rgb_norm = un2linear(rgb_norm);
            xyz = rgbother2xyz(rgb_norm, p.Results.matrix);
        otherwise
            error('Unsupported gamut name!')
    end
        
    % STEP 3
    % calculating x, y in CIE 1931 Yxy of image
    xyzMag = sum(xyz,3);
    x = xyz(:,:,1)./xyzMag;
    y = xyz(:,:,2)./xyzMag;

    % geting x, y of white-point (D65 default) and RGB primaries of gamut
    x_whitepoint = 0.3127;
    y_whitepoint = 0.3290;
    % NOTE: for other white-point:
%     wp = whitepoint(other white-point);
%     wpMag = sum(wp,2);
%     x_whitepoint = wp(:,1)./wpMag;
%     y_whitepoint = wp(:,2)./wpMag;

    % primaries of sRGB gamut will allways be plotted for comparsion
    xs_primary = [0.64 0.30 0.15];
    ys_primary = [0.33 0.60 0.06];
    switch gamut
        case 'bt709'
            x_primary = xs_primary;
            y_primary = ys_primary;
        case 'adobergb'
            x_primary = [0.64 0.21 0.15];
            y_primary = [0.33 0.71 0.06];
        case 'bt2020'
            x_primary = [0.708 0.170 0.131];
            y_primary = [0.292 0.797 0.046];
        case 'other'
            xyz_primaries = squeeze(rgbother2xyz(reshape(...
                [1 0 0; 0 1 0; 0 0 1],[1,3,3]), p.Results.matrix));
            xyzMag = sum(xyz_primaries,2);
            x_primary = (xyz_primaries(:,1)./xyzMag)';
            y_primary = (xyz_primaries(:,2)./xyzMag)';
        otherwise
            error('Unsupported gamut name!')
    end
    
    % STEP 4
    % basic chromaticity diagram with wihte-point and RGB primaries
    plotChromaticity("BrightnessThreshold", 0)
    hold on
    % primaries of sRGB gamut will allways be plotted for comparsion
    scatter(x_whitepoint,y_whitepoint,36,'black')
    scatter(xs_primary,ys_primary,36,'black')
    plot([xs_primary, xs_primary],[ys_primary, ys_primary],'k')
    % primaries of current gamut
    if strcmp(gamut,'bt709') == false
        scatter(x_primary,y_primary,36,'black')
        plot([x_primary, x_primary],[y_primary, y_primary],'k')
    end

    % plotting x,y of image pixels per-row
    shape = size(xyz);
    color_marker = single(rgb)/(2^bit_depth);
    for i=1:shape(1)
        x_val = x(i,:);
        y_val = y(i,:);
        c = squeeze(color_marker(i,:,:));
        scatter(x_val,y_val,6,c,'filled',...
            'MarkerEdgeColor','k','LineWidth',0.25)
    end
end