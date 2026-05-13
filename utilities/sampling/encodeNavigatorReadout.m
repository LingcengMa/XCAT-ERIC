function navLineK = encodeNavigatorReadout(IMG, Coils, navKz)
%ENCODENAVIGATORREADOUT Encode a navigator line along kz at kx=ky=0.
%   navLineK = encodeNavigatorReadout(IMG,Coils,navKz) averages the current
%   coil-weighted 3D image over x/y, applies a z FFT, and samples that kz
%   spectrum at navKz. navKz should be in centered matrix coordinates.
%
%   If navKz is empty or omitted, the full z FFT grid is returned.

navProfile = squeeze(mean(mean(Coils .* IMG,1),2));
if isvector(navProfile)
    navProfile = navProfile(:);
end
navSpectrum = fftshift(fft(navProfile,[],1),1);

if nargin < 3 || isempty(navKz)
    navLineK = navSpectrum;
    return
end

nZ = size(navSpectrum,1);
nCh = size(navSpectrum,2);
zGrid = (-floor(nZ/2)):(ceil(nZ/2)-1);
navKz = navKz(:);
navLineK = complex(zeros(numel(navKz),nCh,'like',navSpectrum));
for coil = 1:nCh
    navLineK(:,coil) = interp1(zGrid(:), navSpectrum(:,coil), double(navKz), 'linear', 0);
end
end
