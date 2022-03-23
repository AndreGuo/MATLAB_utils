# Personal repo of MATLAB utilities.
***Contact me before using any of them academically or commercially.***

`baiGamutDegreeAssessment.m` is the un-official inplementation of 'assessment method on degree of wide color gamut' in paper ['Analysis of high dynamic range and wide color gamut of UHDTV'](https://ieeexplore.ieee.org/document/9390848), with some error fixed and functionality extended.

`delteEitp2124.m` is the un-official inplementation of [ITU-R BT.2124](https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2124-0-201901-I!!PDF-E.pdf), i.e. color difference ***ΔE<sub>ITP</sub>*** for wide-color-gamut (WCG) TV content.

`gamutmap2407hardclip.m` is the un-official inplementation of gamut hard-clipping specified in §2 of [ITU-R BT.2407](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2407-2017-PDF-E.pdf).

`imapplylut.m` apply a look-up table (LUT) on image array, forked from [HERE](https://ww2.mathworks.cn/matlabcentral/fileexchange/43004-imlut-img-lut-kind-order-colorscheme) and modified.

`invtonemap2446m1.m` is the un-official inplementation of inverse tone-mapping (dynamic range extendsion) of METHOD A in [ITU-R BT.2446](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf). Original method is designed for SDR content under BT.2020 colorimetry, we extend this function by adding an optional 'color space transformation (form BT.709 to BT.2020)' to enable its usage on BT.709 SDR content.

`plotImgChromaticity.m` can plot image's pixel color distribution on CIE 1931 Yxy chormaticity diagram, given the assumed gamut (RGB primaries). We rec you to use commercial software like [DaVinci](http://www.blackmagicdesign.com/products/davinciresolve/) for faster and non-vector result.

`tonemap2446m1.m` is the un-official inplementation of tone-mapping (dynamic range compression) of METHOD A in [ITU-R BT.2446](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf).

`tonemap2446m3.m` is the un-official inplementation of tone-mapping (dynamic range compression) of METHOD C in [ITU-R BT.2446](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2446-2019-PDF-E.pdf).
