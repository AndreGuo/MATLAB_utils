function deltaE = delteEitp2124(img, ref, varargin)
    % Copyright: guocheng@cuc.edu.cn, 15 Mar 2022
    %
    % Un-official implementation of HDRTV color difference deltaEitp 
    % discribed in ITU-R BT.2214
    %
    % Input argsuments:
    %  Required (2):
    %  'img' & 'ref'  - m-by-n-by-3 RGB (BGR not supported) image array,
    %                   non-linear, normalized to [0,1]
    %                   single | double
    %
    %  Optional (2):
    %  'oetf'         - char:
    %                   'PQ' (default) | 'HLG' | 'gamma'
    %  'output_deltaE_map': (our extension)
    %                    enter its filename TO output a normalized heatmap
    %                    telling the position & degree of color difference.
    %                    DONOT USE NOW
    %
    % Output argments (1):
    %  'deltaE'       - num:
    %                   average deltaEitp value of the whole image.

    p = inputParser;
    addRequired(p,'img',@(x)validateattributes(x,...
        {'numeric'},{'size',[NaN,NaN,3]}))
    addOptional(p,'oetf','PQ',@(x)validateattributes(x,...
        {'char'},{'nonempty'}))
    addOptional(p,'output_deltaE_map','')
    parse(p,img,varargin{:})

    % Read normalized non-linear image [0,1]
    rgb2020_ = img;
    rgb2020_ref_ = ref;
    
    % linearize
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
            eotf = @(x)(x.^(1/0.45));
        otherwise
            error('Unsupported OETF!')
    end
  
    rgb2020 = eotf(rgb2020_);
    rgb2020_ref = eotf(rgb2020_ref_);

    % STEP 1: linear RGB2020 to LMS
    matrix = @(rgb,m)(cat(3,...
        (m(1,1)*rgb(:,:,1)+m(1,2)*rgb(:,:,2)+m(1,3)*rgb(:,:,3)),...
        (m(2,1)*rgb(:,:,1)+m(2,2)*rgb(:,:,2)+m(2,3)*rgb(:,:,3)),...
        (m(3,1)*rgb(:,:,1)+m(3,2)*rgb(:,:,2)+m(3,3)*rgb(:,:,3))));
    rgb2020tolms = [1688 2146 262;...
                    683 2951 462;...
                    99 309 3688]/4096;
    lms = matrix(rgb2020, rgb2020tolms);
    lms_ref = matrix(rgb2020_ref, rgb2020tolms);

    % STEP 2: linear LMS to non-linear LMS_
    switch p.Results.oetf
        case 'PQ'
            oetf = @(x)(((c1+c2*(x.^m1))./(1+c3*(x.^m1))).^m2);
        case 'HLG'
            oetf = @(x)((sqrt(3*x)).*(x>=0 & x<=1/12) +...
                (a*log(12*x-b)+c).*(x>1/12 & x<=1));
        case 'gamma'
            oetf = @(x)(x.^0.45);
        otherwise
            error('Unsupported OETF!')
    end

    lms_ = oetf(lms);
    lms_ref_ = oetf(lms_ref);

    % STEP 3 & 4: non-linear LMS to ICtCp to ITP (T=0.5Ct, P=Cp)
    switch p.Results.oetf
        case 'PQ'
            lmstoitp = [2048 2048 0;...
                        3305 -6806.5 3501.5;...
                        17933 -17390 -543]/4096;
        case 'HLG'
            lmstoitp = [2048 2048 0;...
                        1812.5 -3732.5 1920;...
                        9500 -9212 -288]/4096;
        case 'gamma'
            lmstoitp = [2048 2048 0;...
                        1812.5 -3732.5 1920;...
                        9500 -9212 -288]/4096;
            warning(['ICtCp is only designed for PQ and HLG signal....' ...
                '! Here, we use the HLG''s formula for gamma signal.'])
        otherwise
            error('Unsupported OETF!')
    end

    itp = matrix(lms_, lmstoitp);
    itp_ref = matrix(lms_ref_, lmstoitp);

    % STEP 5: Calculating deltaEitp
    I = itp(:,:,1); Ir = itp_ref(:,:,1);
    T = itp(:,:,2); Tr = itp_ref(:,:,2);
    P = itp(:,:,3); Pr = itp_ref(:,:,3);
    deltaE_map = 720*sqrt((I-Ir).^2 + (T-Tr).^2 + (P-Pr).^2);
    deltaE = mean(deltaE_map(:));

    % (Optional) output deltaE heatmap
    if isempty(p.Results.output_deltaE_map) == false
        % Normalize
        % DO NOT USE IT NOW, SINCE WE DON'T KNOW HOW TO NORMALIZE DELTAE
        imwrite(deltaE_map, trubo(60), p.Results.output_deltaE_map)
        % imshow(deltaE_map, [], 'Border','tight');
        % colormap('jet');
        % exportgraphics(gca,p.Results.deltaE_map,'Resolution', 300)
    end