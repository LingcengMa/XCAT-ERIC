function stats = estimateIsotropicVolumeSize(matrixXYZ, frameRateHz, durationMin, precision)
%ESTIMATEISOTROPICVOLUMESIZE Estimate memory footprint of isotropic 4D ground truth.

if nargin < 4
    precision = 'single';
end

nFrames = round(durationMin*60*frameRateHz);
voxPerFrame = prod(matrixXYZ);
bytesPerVoxel = 4;
switch lower(precision)
    case 'double'
        bytesPerVoxel = 8;
    case 'single'
        bytesPerVoxel = 4;
end

bytesTotal = voxPerFrame * nFrames * bytesPerVoxel;
stats = struct();
stats.matrixXYZ = matrixXYZ;
stats.frameRateHz = frameRateHz;
stats.durationMin = durationMin;
stats.nFrames = nFrames;
stats.bytesTotal = bytesTotal;
stats.gibTotal = bytesTotal / (1024^3);
end

