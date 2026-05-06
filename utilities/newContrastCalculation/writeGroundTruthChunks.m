function metadata = writeGroundTruthChunks(app, outDir, nFrames, framesPerChunk, frameGenerator)
%WRITEGROUNDTRUTHCHUNKS Generate and save GT frames in chunks (frame-driven).
% frameGenerator: @(app,frameIdx,state) IMG
% Optional app controls:
%   app.gtMaxFrames  - generate only the first N frames for a fast preflight
%   app.gtStatusFile - custom status log path

if ~exist(outDir,'dir')
    mkdir(outDir);
end
if nargin < 5 || ~isa(frameGenerator,'function_handle')
    error('frameGenerator must be @(app,frameIdx,state) IMG');
end

framesPerChunk = max(1, round(framesPerChunk));
maxFrames = nFrames;
if isprop(app,'gtMaxFrames') && ~isempty(app.gtMaxFrames)
    maxFrames = min(nFrames, max(0, floor(app.gtMaxFrames)));
end

statusFile = fullfile(outDir,'gt_generation_status.txt');
if isprop(app,'gtStatusFile') && ~isempty(app.gtStatusFile)
    statusFile = app.gtStatusFile;
end

fid = fopen(statusFile,'w');
fprintf(fid,'GT chunk generation started: %s\n', datestr(now));
fprintf(fid,'Output directory: %s\n', outDir);
fprintf(fid,'Requested frames: %d\n', nFrames);
fprintf(fid,'Frames to generate: %d\n', maxFrames);
fprintf(fid,'Frames per chunk: %d\n', framesPerChunk);
fclose(fid);

nChunks = ceil(maxFrames/framesPerChunk);
state = struct();
metadata = struct('outDir',outDir, 'statusFile',statusFile, ...
    'nFramesRequested',nFrames, 'nFramesGenerated',maxFrames, ...
    'framesPerChunk',framesPerChunk, 'nChunks',nChunks);

for c = 1:nChunks
    fStart = (c-1)*framesPerChunk + 1;
    fEnd = min(c*framesPerChunk, maxFrames);
    nLocal = fEnd - fStart + 1;

    for k = 1:nLocal
        frameIdx = fStart + k - 1;
        IMG = frameGenerator(app, frameIdx, state);
        if k == 1
            GTchunk = zeros([size(IMG), nLocal], 'like', IMG);
        end
        GTchunk(:,:,:,k) = IMG;
        clear IMG
    end

    chunkFile = fullfile(outDir, sprintf('gt_chunk_%04d.mat', c));
    save(chunkFile, 'GTchunk', 'fStart', 'fEnd', '-v7.3');
    clear GTchunk

    fid = fopen(statusFile,'a');
    fprintf(fid,'Wrote %s (frames %d-%d): %s\n', chunkFile, fStart, fEnd, datestr(now));
    fclose(fid);
    disp(['Wrote GT chunk: ' chunkFile]);
end

fid = fopen(statusFile,'a');
fprintf(fid,'GT chunk generation completed: %s\n', datestr(now));
fclose(fid);
end

