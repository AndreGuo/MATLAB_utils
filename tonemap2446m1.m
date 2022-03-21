function RGBTMO_ = tonemap2446m1(img, varargin)
    % Copyright: guocheng@cuc.edu.cn, 21 Mar 2022
    %
    % Un-official implementation of HDRTV-to-SDR down-conversion 
    % METHOD A of ITU-R BT.2446
    %
    % Input argsuments:
    %  Required (1):
    %  'img'          - m-by-n-by-3 RGB (BGR not supported) image array,
    %                   non-linear, normalized to [0,1]
    %                   single | double
    %
    %  Optional (4):
    %  'oetf'         - char:
    %                   'PQ' (default) | 'HLG' | 'gamma'
    %  'color_scaling'- bool:
    %                   specify if applying color scaling function
    %                   accroding to original recomendation
    %                   true (default) | false
    %  'l_hdr/l_sdr'  - num:
    %                   the asummed peak luminance of HDR/SDR display
    %                   1000/100 (default)
    %
    % Output argments (1):
    %  'RGBTMO_'      - m-by-n-by-3 RGB image array in [0,1]
    %                   normalized tone-mapped SDR, in BT.709/2020 
    %                   non-linearity, in same BT.2020 gamut

    p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addOptional(p,'oetf','PQ',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'color_scaling',false,@(x)validateattributes(x,...
        {'logical'},{'nonempty'}))
    addOptional(p,'l_hdr',1000,@(x)validateattributes(x,...
        {'numeric'},{'nonempty'}))
    addOptional(p,'l_sdr',100,@(x)validateattributes(x,...
        {'numeric'},{'nonempty'}))
    parse(p,img,varargin{:})
    
    % assume a [0,1] normalized input in single/double
    hdr2020_ = img;

    % 5.1.1 Conversion to linear display light signals
    switch p.Results.oetf
        case 'PQ'
            m1 = 2610/16384; m2 = 2523/32;...
                c1 = 3424/4096; c2 = 2413/128; c3 = 2392/128;
            eotf = @(x)((max((x.^(1/m2)-c1), zeros(size(x)))...
                ./(c2-c3.*(x.^(1/m2)))).^(1/m1));
        case 'HLG'
            a = 0.17883277; b = 0.02372241; c = 1.00429347;
            eotf = @(x)(((x.^2)/3).*(x>=0 & x<=1/2) +...
                (exp((x-c)/a)+b).*(x>1/2 & x<=1));
        case 'gamma'
            eotf = @(x)(x.^2.2);
        otherwise
            error('Unsupported OETF!')
    end

    % linearize
    hdr2020 = eotf(hdr2020_);

    % TABLE 1 RAW 1: non-linear transfer function
    nltf = @(x)(x.^(1/2.4));
    hdr2020_ = nltf(hdr2020);

    % TABLE 1 RAW 2: luma
    Y_ = 0.2627*hdr2020_(:,:,1) + 0.6780*hdr2020_(:,:,2)...
        + 0.0593*hdr2020_(:,:,3);

    % TABLE 1 RAW 3: tonemapping step 1
    rhoHDR = 1+32*(p.Results.l_hdr/10000)^(1/2.4); % 13.2598;
    Yp_ = log10(1+(rhoHDR-1).*Y_)./log10(rhoHDR);

    % TABLE 1 RAW 4: tonemapping step 2
    tm2 = @(x)((1.0770*x).*(x>=0 & x<=0.7399) + ...
        (-1.1510*(x.^2)+2.7811*x-0.6302).*(x>.7399 & x<0.9909) + ...
        (0.5*x+0.5).*(x>=0.9909 & x<=1));
    Yc_ = tm2(Yp_);

    % TABLE 1 RAW 5: tonemapping step 3
    rhoSDR = 1+32*(p.Results.l_sdr/10000)^(1/2.4); % 5.6970
    YSDR_ = (rhoSDR.^Yc_ - 1)./(rhoSDR - 1);

    % TABLE 2 RAW 1 & 2: color differencr signals
    % after color scaling function
    switch p.Results.color_scaling
        case true
            CbTMO_ = (YSDR_.*(hdr2020_(:,:,3)-Y_))./(2.06954*Y_);
            CrTMO_ = (YSDR_.*(hdr2020_(:,:,1)-Y_))./(1.62206*Y_);
        case false
            CbTMO_ = (hdr2020_(:,:,3)-Y_)./1.8814;
            CrTMO_ = (hdr2020_(:,:,1)-Y_)./1.4746;
        otherwise
            error('Unsupportted color_scaling (bool) !');
    end

    % TABLE 2 RAW 3: adjust luma component
    YTMO_ = YSDR_-max(0.1*CrTMO_, zeros(size(CrTMO_)));

    % TABLE 2 RAW 4: color space conversion
    % we didn't use func. ycbcr2rgbwide() introduced in ver 2020b for
    % following reason: 1. it process limit-range, unnormalized value;
    % 2. it's designed for 
    ycbcrtorgb = [1.00000 -1.01295e-06 1.47460;...
        0.98390	-0.16190 -0.56215;...
        1.18404	1.85112	-0.10515];
    matrix = @(rgb,m)(cat(3,...
        (m(1,1)*rgb(:,:,1)+m(1,2)*rgb(:,:,2)+m(1,3)*rgb(:,:,3)),...
        (m(2,1)*rgb(:,:,1)+m(2,2)*rgb(:,:,2)+m(2,3)*rgb(:,:,3)),...
        (m(3,1)*rgb(:,:,1)+m(3,2)*rgb(:,:,2)+m(3,3)*rgb(:,:,3))));
    YCbCrTMO_ = cat(3, YTMO_, CbTMO_, CrTMO_);
    RGBTMO_ = matrix(YCbCrTMO_, ycbcrtorgb);
