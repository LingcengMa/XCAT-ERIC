function [GT, frameTimesSec, meta] = readGroundTruthChunks(gtChunkDir, frameTimeSec)
%READGROUNDTRUTHCHUNKS Reassemble all gt_chunk_####.mat files.
%   [GT,frameTimesSec,meta] = readGroundTruthChunks(gtChunkDir,frameTimeSec)
%   loads GTchunk variables from all gt_chunk_####.mat files in gtChunkDir
%   and concatenates them into one 4D array GT(:,:,:,frame).
%
%   frameTimeSec is optional. For SR-GRE chunks with 168 local frames per
%   contrast sample, use contrastSamplingSec/168. For example, if contrast
%   sampling is 1.008 s, the GT frame spacing is 1.008/168 = 0.006 s:
%       [GT,t,meta] = readGroundTruthChunks(gtChunkDir,0.006);
%
%   This reconstructs the full GT movie in memory. For very large runs, use
%   the chunk files directly instead of concatenating all frames.

if nargin < 1 || isempty(gtChunkDir)
    error('readGroundTruthChunks:MissingInput','gtChunkDir is required.');
end
if nargin < 2 || isempty(frameTimeSec)
    frameTimeSec = [];
end
if ~exist(gtChunkDir,'dir')
    error('readGroundTruthChunks:MissingDirectory','GT chunk directory does not exist: %s', gtChunkDir);
end

files = dir(fullfile(gtChunkDir,'gt_chunk_*.mat'));
if isempty(files)
    error('readGroundTruthChunks:NoChunks','No gt_chunk_*.mat files found in: %s', gtChunkDir);
end
[~,idx] = sort({files.name});
files = files(idx);

frameRanges = zeros(numel(files),2);
totalFrames = 0;
volSize = [];
for c = 1:numel(files)
    chunkPath = fullfile(gtChunkDir,files(c).name);
    info = whos('-file',chunkPath);
    names = {info.name};
    if ~ismember('GTchunk',names)
        error('readGroundTruthChunks:BadChunk','Missing GTchunk in %s', chunkPath);
    end
    datInfo = info(strcmp(names,'GTchunk'));
    thisSize = datInfo.size;
    if numel(thisSize) < 4
        thisSize(4) = 1;
    end
    if isempty(volSize)
        volSize = thisSize(1:3);
    elseif any(volSize ~= thisSize(1:3))
        error('readGroundTruthChunks:SizeMismatch','GTchunk volume size mismatch in %s', chunkPath);
    end

    frameRange = getStoredFrameRange(chunkPath, totalFrames + 1, totalFrames + thisSize(4));
    frameRanges(c,:) = frameRange;
    totalFrames = max(totalFrames, frameRange(2));
end

first = load(fullfile(gtChunkDir,files(1).name),'GTchunk');
GT = zeros([volSize totalFrames],'like',first.GTchunk);
for c = 1:numel(files)
    chunkPath = fullfile(gtChunkDir,files(c).name);
    dat = load(chunkPath,'GTchunk');
    f1 = frameRanges(c,1);
    f2 = frameRanges(c,2);
    nLocal = f2 - f1 + 1;
    GT(:,:,:,f1:f2) = dat.GTchunk(:,:,:,1:nLocal);
end

if isempty(frameTimeSec)
    frameTimesSec = [];
else
    frameTimesSec = (0:totalFrames-1) * frameTimeSec;
end

meta = struct();
meta.gtChunkDir = gtChunkDir;
meta.files = {files.name};
meta.nChunks = numel(files);
meta.volumeSize = volSize;
meta.nFrames = totalFrames;
meta.frameRanges = frameRanges;
meta.frameTimeSec = frameTimeSec;
meta.durationSec = [];
if ~isempty(frameTimesSec)
    meta.durationSec = frameTimesSec(end) + frameTimeSec;
end
end

function frameRange = getStoredFrameRange(chunkPath, fallbackStart, fallbackEnd)
vars = whos('-file',chunkPath);
names = {vars.name};
if all(ismember({'fStart','fEnd'},names))
    s = load(chunkPath,'fStart','fEnd');
    frameRange = [s.fStart s.fEnd];
elseif all(ismember({'i1','i2'},names))
    s = load(chunkPath,'i1','i2');
    frameRange = [s.i1 s.i2];
elseif all(ismember({'roStart','roEnd'},names))
    s = load(chunkPath,'roStart','roEnd');
    frameRange = [s.roStart s.roEnd];
else
    frameRange = [fallbackStart fallbackEnd];
end
frameRange = double(frameRange);
end
