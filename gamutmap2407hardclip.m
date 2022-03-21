function rgb709_hc = gamutmap2407hardclip(img, varargin)
    % Copyright: guocheng@cuc.edu.cn, 3 Mar 2022
    %
    % Un-official implementation of basic gamut mapping (hard-clipping) 
    % i.e. §2 of ITU-R BT.2407
    %
    % Recommend to use after tone-mapping (non-linearity is 'gamma' now).
    %
    % Input argsuments:
    %  Required (1):
    %  'img'          - m-by-n-by-3 RGB (BGR not supported) image array,
    %                   nonlinear, normalized to [0,1]
    %                   single | double 
    %
    %  Optional (2):
    %  'oetf'         - char:
    %                   'gamma' (default, refer to oetf of BT.709/2020)
    %                   'PQ' | 'HLG' | (use for HDR img (not tone-mapped))
    %  'target_gamut' - char:
    %                   'srgb' (default) | 'adobergb'
    %
    % Output argments (1):
    %  'rgb709_hc'    - m-by-n-by-3 RGB image array in [0,1]
    %                   normalized gamut-mapped SDR, in gamma non-linear
    %                   and BT.709/srgb or adobergb gamut
    %
    % Require MATLAB version >= 2020b for 'rgbwide2xyz()'
    
    p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addOptional(p,'oetf','gamma',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'target_gamut','srgb',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    parse(p,img,varargin{:})

    % assume a [0,1] normalized input
    rgb2020_ = img;
    % convert to [0,1] to 12-bit full range uint16 [0,4095]
    rgb2020_ = uint16(rgb2020_*(2^12-1));

    % !!! map 58% PQ to SDR reference white ???
    % rgb2020 = (4095.0/2376.0)*rgb2020;
    % rgb2020(rgb2020>4095) = 4095;

    % convert full-range to limit-range to suit 'rgbwide2xyz()'
    full_2_limited = @(x)(0.85546875*x+256);
    rgb2020_limit = full_2_limited(rgb2020_);

    % rgb2020_ to xyz
    switch p.Results.oetf
        case 'PQ'
            xyz = rgbwide2xyz(rgb2020_limit,12,'ColorSpace','BT.2100');
        case 'HLG'
            xyz = rgbwide2xyz(rgb2020_limit,12,'ColorSpace','BT.2100',...
                'LinearizationFcn','HLG');
        case 'gamma'
            xyz = rgbwide2xyz(rgb2020_limit,12,'ColorSpace','BT.2020');
        otherwise
            error('Unsupported OETF!')
    end

    % xyz to gamma-nonlinear
    switch p.Results.target_gamut
        case 'srgb'
            rgb709_ = xyz2rgb(xyz,'ColorSpace','srgb');
        case 'adobergb'
            rgb709_ = xyz2rgb(xyz,'ColorSpace','adobe-rgb-1998');
        otherwise
            error('Unsupported Targrt Gamut!')
    end

    % gamut hard clipping
    % NOTE THAT hard clipping SHOULD accually be conducted on LINEAR rgb709
    % value, but it's OK to conduct on gamma-nonlinear value since linear-
    % value outside [0,1] will fall exactly outside [0,1] when nonlinear.
    rgb709_hc = rgb709_;
    rgb709_hc(rgb709_hc<0) = 0;
    rgb709_hc(rgb709_hc>1) = 1;
