function sdr2020_ = tonemap2446m3(img, varargin)
    % Copyright: guocheng@cuc.edu.cn, 3 Mar 2022
    %
    % Un-official implementation of HDRTV-to-SDR down-conversion 
    % METHOD C of ITU-R BT.2446
    %
    % Input argsuments:
    %  Required (1):
    %  'img'          - m-by-n-by-3 RGB (BGR not supported) image array,
    %                   non-linear, normalized to [0,1]
    %                   single | double
    %
    %  Optional (3):
    %  'oetf'         - char:
    %                   'PQ' (default) | 'HLG' | 'gamma'
    %  'alpha'        - num:
    %                   determines the degree of de-saturation
    %                   0.05 (default) | should range [0, 0.33]
    %  'linear_output'- bool:
    %                   if output SDR array is linear 
    %                   false (default) | true
    %
    % Output argments (1):
    %  'sdr2020_'     - m-by-n-by-3 RGB image array in [0,1]
    %                   normalized tone-mapped SDR, can be linear or 
    %                   BT.709/2020 non-linearity, in same BT.2020 gamut

    p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addOptional(p,'oetf','PQ',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'alpha',0.05,@(x)validateattributes(x,...
        {'numeric'},{'nonempty'}))
    addOptional(p,'linear_output',false,@(x)validateattributes(x,...
        {'logical'},{'nonempty'}))
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
            a = 0.17883277; b = 0.28466892; c = 0.55991073;
            eotf = @(x)(((x.^2)/3).*(x>=0 & x<=1/2) +...
                ((exp((x-c)/a)+b)/12).*(x>1/2 & x<=1));
        case 'gamma'
            eotf = @(x)(x.^2.2);
        otherwise
            error('Unsupported OETF!')
    end
    hdr2020 = eotf(hdr2020_);
    % convert [0,1] to absolute luminance [0,1000]
    hdr2020 = hdr2020*1000.0;

    % 5.1.2 Crosstalk matrix
    matrix = @(rgb,m)(cat(3,...
        (m(1,1)*rgb(:,:,1)+m(1,2)*rgb(:,:,2)+m(1,3)*rgb(:,:,3)),...
        (m(2,1)*rgb(:,:,1)+m(2,2)*rgb(:,:,2)+m(2,3)*rgb(:,:,3)),...
        (m(3,1)*rgb(:,:,1)+m(3,2)*rgb(:,:,2)+m(3,3)*rgb(:,:,3))));
    alp = p.Results.alpha;
    cross_talk = [1-2*alp alp alp;...         
                  alp 1-2*alp alp;...
                  alp alp 1-2*alp;];
    hdr2020 = matrix(hdr2020, cross_talk);

    % 5.1.3 Conversion to Yxy
    % RGB2020 to XYZ
    rgb2020toxyz = [0.6370 0.1446 0.1689;...
                    0.2627 0.6780 0.0593;...
                    0.0000 0.0281 1.0610];
    xyz = matrix(hdr2020, rgb2020toxyz);
    % XYZ to Yxy
    Y = xyz(:,:,2); % should range [0,1000] for tonemap below
    xyzMag = sum(xyz,3);
    x = xyz(:,:,1)./xyzMag;
    y = xyz(:,:,2)./xyzMag;

    % 5.1.4 Tone mapping
    % !!! default params below are derived for HLG, in BT.2446
    k1 = 0.83802; k2 = 15.09968; k3 = 0.74204; k4 = 78.99439; Yip = 58.5/k1;
    % map [0,1000] to [0,118.3868]
    tonemap = @(x)((k1*x).*(x>=0 & x<Yip)+...
                    (k2*log(x/Yip-k3)+k4).*(x>=Yip));
    Y = tonemap(Y);
    % !!! how to deal with value above 100% to coded-109%/linear-118% ???
    % OPTION 1 normalize ???
    % Y = Y/118.3868;
    % OPTION 2 clamp ???
    Y(Y>100) = 100;

    % 5.1.5 Conversion to RGB linear signal
    X = (x./y).*Y;
    Z = ((1-x-y)./y).*Y;
    xyz = cat(3, X, Y, Z);
    xyztosdr2020 = [1.7167 -0.3557 -0.2534;...
                    -0.6667 1.6165 0.0158;...
                    0.0176 -0.0428 0.9421];
    % xyztosdr2020 = inv(rgb2020toxyz);
    sdr2020 = matrix(xyz, xyztosdr2020);

    % 5.1.6 Inverse crosstalk matrix
    inv_cross_talk = inv(cross_talk);
    sdr2020 = matrix(sdr2020, inv_cross_talk);

    % 5.1.7 Inverse SDR EOTF (optional)
    sdr2020(sdr2020<0) = 0;
    % normalized SDR to [0,1]
    sdr2020_ = (sdr2020./100.0);
    if p.Results.linear_output == false
        % add non-linearity
        gammaoetf = @(x)(((1.099*x.^0.45)-0.099).*(x<=1 & x>=0.018)+...
            (4.5*x).*(x>=0 & x<0.018));
        sdr2020_ = gammaoetf(sdr2020);
    end

