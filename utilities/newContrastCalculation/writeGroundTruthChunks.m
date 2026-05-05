function writeGroundTruthChunks(app, outDir, nFrames, framesPerChunk, frameGenerator)
%WRITEGROUNDTRUTHCHUNKS Generate and save GT frames in chunks (frame-driven).
% frameGenerator: @(app,frameIdx,state) IMG

if ~exist(outDir,'dir')
    mkdir(outDir);
end
if nargin < 5 || ~isa(frameGenerator,'function_handle')
    error('frameGenerator must be @(app,frameIdx,state) IMG');
end

nChunks = ceil(nFrames/framesPerChunk);
state = struct();

for c = 1:nChunks
    fStart = (c-1)*framesPerChunk + 1;
    fEnd = min(c*framesPerChunk, nFrames);
    nLocal = fEnd - fStart + 1;

    for k = 1:nLocal
        frameIdx = fStart + k - 1;
        IMG = frameGenerator(app, frameIdx, state);
        if k == 1
            GTchunk = zeros([size(IMG), nLocal], 'like', IMG);
        end
        GTchunk(:,:,:,k) = IMG;
    end

    chunkFile = fullfile(outDir, sprintf('gt_chunk_%04d.mat', c));
    save(chunkFile, 'GTchunk', 'fStart', 'fEnd', '-v7.3');
    clear GTchunk
end

