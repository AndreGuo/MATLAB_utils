function RGB_ = invtonemap2446m1(img, varargin)
    % Copyright: guocheng@cuc.edu.cn, 22 Mar 2022
    %
    % Un-official implementation of SDR-to-HDRTV up-conversion 
    % METHOD A of ITU-R BT.2446
    %
    % Input argsuments:
    %  Required (1):
    %  'img'          - m-by-n-by-3 RGB (BGR not supported) image array,
    %                   non-linear, normalized to [0,1]
    %                   single | double
    %
    %  Optional (5):
    %  'expand_gamut'-  bool:
    %                   OUR EXTANDSION
    %                   set it true when input SDR is in BT.709 primaries 
    %                   true (default) |
    %                   false (when input SDR already in bt.2020 primaries)
    %  'wcg_oetf'     - char:
    %                   works only when 'expand_gamut' == true
    %                   'PQ' (default) | 'HLG' | 'gamma'
    %  'linear_output'- bool:
    %                   if output SDR array is linear 
    %                   false (default) | true
    %  'color_scaling'- bool:
    %                   specify if applying color scaling function
    %                   accroding to original recomendation
    %                   true (default) | false
    %  'l_hdr'        - num:
    %                   the asummed peak luminance of target HDR display
    %                   1000 (default)
    %                   DEPRECATED IN CURRENT VERSION !!!
    %
    % Output argments (1):
    %  'RGB_'         - m-by-n-by-3 RGB image array in [0,1]
    %                   normalized HDR, in BT.709/2020 non-linearity
    %                   (~gamma(1/0.45)), in same BT.709 gamut TODO

    p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addOptional(p,'expand_gamut',true,@(x)validateattributes(x,...
        {'logical'},{'nonempty'}))
    addOptional(p,'wcg_oetf','PQ',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'linear_output',false,@(x)validateattributes(x,...
        {'logical'},{'nonempty'}))
    addOptional(p,'color_scaling',true,@(x)validateattributes(x,...
        {'logical'},{'nonempty'}))
    addOptional(p,'l_hdr',1000,@(x)validateattributes(x,...
        {'numeric'},{'nonempty'}))
    parse(p,img,varargin{:})

    RGB_ = img;
    % OUR EXTENDSION:
    % This method takes input SDR signals with BT.2020 colorimetry, so SDR
    % in BT.709 primaries must be converted to BT.2020 first.   
    matrix = @(rgb,m)(cat(3,...
        (m(1,1)*rgb(:,:,1)+m(1,2)*rgb(:,:,2)+m(1,3)*rgb(:,:,3)),...
        (m(2,1)*rgb(:,:,1)+m(2,2)*rgb(:,:,2)+m(2,3)*rgb(:,:,3)),...
        (m(3,1)*rgb(:,:,1)+m(3,2)*rgb(:,:,2)+m(3,3)*rgb(:,:,3))));
    if p.Results.expand_gamut == true
        % linearize
        RGB = RGB_.^(1/0.45);
        % convert bt.709 RGB to bt.2020 container
        rgb709torgb2020 = [0.62742 0.32928 0.04331;...
                           0.06910 0.91954 0.01136;...
                           0.01639 0.08803 0.89558];
        RGB = matrix(RGB, rgb709torgb2020);
        % add non-linearity
        RGB_ = RGB.^0.45;
    end

    % Now, RGB_ should be in BT.2020 gamut primaries, gamma0.45 non-linear
    %{
    rgb709_2ycbcr_ = [0.2126 0.7152 0.0722;...
                      -0.11457 -0.38543 0.5;...
                      0.5 -0.45415 -0.04585];
    %}
    rgb2020_2ycbcr_ = [0.2627 0.6780 0.0593;...
                       -0.13963 -0.36037 0.5;...
                       0.5 -0.45979 -0.04021];
    YCbCr_ = matrix(RGB_, rgb2020_2ycbcr_);
    % TABLE 3 RAW 1 & 2: range adjustment [0,1] to [0,255]
    Y__ = 255.0*YCbCr_(:,:,1);

    % TABLE 3 RAW 3-5: SDR to HDR luma mapping
    a1 = 1.8712e-5; b1 = -2.7334e-3; c1 = 1.3141;
    a2 = 2.8305e-6; b2 = -7.4622e-4; c2 = 1.2528;
    expval = @(x)((a1*x.^2 + b1*x + c1).*(x<=70) + ...
        (a2*x.^2 + b2*x + c2).*(x>70));
    YHDR_ = Y__.^expval(Y__); % [0,1000]

    % TABLE 3 RAW 6 & 7: chroma mapping with scaling factor
    %!!! ???
    % Cb_ = Cb_*1000.0; Cr_ = Cr_*1000.0; 

    switch p.Results.color_scaling
        case true
            Y_ = YCbCr_(:,:,1);
            SC = (1.075*(YHDR_./Y_)).*(Y_>0) + 1.*(Y_==0);
            CbHDR_ = YCbCr_(:,:,2).*SC; CrHDR_ = YCbCr_(:,:,3).*SC;
        case false
            CbHDR_ = YCbCr_(:,:,2); CrHDR_ = YCbCr_(:,:,3);
        otherwise
            error('Unsupportted color_scaling (bool) !');
    end

    % TABLE 3 RAW 8 & 9: absolute HDR
    R_ = YHDR_+1.4746*CrHDR_;
    G_ = YHDR_-0.16455*CbHDR_-0.57135*CrHDR_;
    B_ = YHDR_+1.8814*CbHDR_;
    RGB_ = cat(3,R_,G_,B_)/1000.0;
    % clamp to [0,1] ([0,1000])
    RGB_(RGB_>1) = 1;
    RGB_(RGB_<0) = 0;
    % linearize
    RGB = RGB_.^2.4;
    % RGB value here is scene-refered ('absolute HDR'), and can be be send
    % to encode into PQ system if multiplied with p.Results.l_hdr (1000.0)
    switch p.Results.linear_output
        case false
            % add non-linearity
            switch p.Results.wcg_oetf
                case 'PQ'
                    m1 = 2610/16384; m2 = 2523/32;...
                        c1 = 3424/4096; c2 = 2413/128; c3 = 2392/128;
                    oetf = @(x)(((c1+c2*(x.^m1))./(1+c3*(x.^m1))).^m2);
                case 'HLG'
                    a = 0.17883277; b = 0.28466892; c = 0.55991073;
                    oetf = @(x)((sqrt(3*x)).*(x>=0 & x<=1/12) +...
                        (a*log(12*x-b)+c).*(x>1/12 & x<=1));
                case 'gamma'
                    oetf = @(x)(x.^0.45);
                otherwise
                    error('Unsupportted wcg_oetf!')
            end
            RGB_ = oetf(RGB);
        case true
            RGB_ = RGB;
        otherwise
            error('Unsupportted linear_output!')
    end
