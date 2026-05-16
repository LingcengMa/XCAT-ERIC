function kline = encodeOneNonCartesianReadout(IMGcoil, kx, ky, kz, app, kzConvention)
%ENCODEONENONCARTESIANREADOUT Encode one non-Cartesian readout using existing conventions.
%   Supports either legacy 1-based kz samples (1..matrixFH) or centered
%   stack-of-stars kz coordinates (-floor(matrixFH/2)..ceil(matrixFH/2)-1).

if nargin < 6 || isempty(kzConvention)
    kzConvention = 'auto';
end
nZ = size(IMGcoil,3);
[x, y, z, slIdx] = buildReadoutKloc(kx, ky, kz, app, nZ, kzConvention);

kloc = cat(3,y,x,z);
kloc = permute(kloc, [3 1 2]);

tmp2 = fft(ifftshift(IMGcoil,3),[],3); % same z-FFT convention as sampleKSpace.m

kloc2 = kloc;
kloc2(3,:,:) = 0;
obj = nufft_3d(kloc2,[app.matrixAP app.matrixRL 1],'radial',1,'gpu',0);
kline = obj.fNUFT(squeeze(tmp2(:,:,slIdx)));
kline = reshape(kline, [], 1);
end

function [x, y, z, slIdx] = buildReadoutKloc(kx, ky, kz, app, nZ, kzConvention)
x = kx(:) * app.matrixRL;
y = ky(:) * app.matrixAP;
[kzCentered, slIdx] = normalizeKzSamples(kz, nZ, kzConvention);

% The current stack-of-stars path encodes one kz partition per readout using
% a 2-D NUFFT after FFT along z.  Guard against an accidental kz-varying
% readout, which would require a true 3-D NUFFT instead.
if any(slIdx ~= slIdx(1))
    error('encodeOneNonCartesianReadout:VaryingKzReadout', ...
        ['One-readout non-Cartesian encoding expects a fixed kz partition. ' ...
        'Received %d unique kz sample indices.'], numel(unique(slIdx)));
end
slIdx = slIdx(1);
z = repmat(kzCentered(1), size(x));
end

function [kzCentered, slIdx] = normalizeKzSamples(kz, nZ, kzConvention)
kz = double(kz(:));
kzRound = round(kz);
centerMin = -floor(nZ/2);
centerMax = ceil(nZ/2) - 1;

switch lower(kzConvention)
    case {'centered','matrix-centered','stackofstars','stack-of-stars'}
        isValid = all(kzRound >= centerMin & kzRound <= centerMax);
        if ~isValid
            error('encodeOneNonCartesianReadout:InvalidCenteredKz', ...
                'Centered kz samples must be in %d..%d.', centerMin, centerMax);
        end
        kzCentered = kzRound;
        slIdx = kzRound + floor(nZ/2) + 1;
        return
    case {'onebased','1based','legacy'}
        isValid = all(kzRound >= 1 & kzRound <= nZ);
        if ~isValid
            error('encodeOneNonCartesianReadout:InvalidOneBasedKz', ...
                '1-based kz samples must be in 1..%d.', nZ);
        end
        slIdx = kzRound;
        kzCentered = kzRound - nZ/2;
        return
end

if all(kzRound >= centerMin & kzRound <= centerMax) && any(kzRound <= 0)
    % Stack-of-stars centered coordinates are unambiguous when non-positive.
    kzCentered = kzRound;
    slIdx = kzRound + floor(nZ/2) + 1;
elseif all(kzRound >= 1 & kzRound <= nZ)
    % Legacy app.kz_samples convention: MATLAB 1-based FFT slice indices.
    slIdx = kzRound;
    kzCentered = kzRound - nZ/2;
elseif all(kzRound >= 0 & kzRound <= nZ-1)
    % Defensive support for zero-based FFT slice indices.
    slIdx = kzRound + 1;
    kzCentered = slIdx - nZ/2;
else
    error('encodeOneNonCartesianReadout:InvalidKz', ...
        'kz samples must be 1..%d, 0..%d, or centered %d..%d.', ...
        nZ, nZ-1, centerMin, centerMax);
end

slIdx = min(max(1, slIdx), nZ);
end
