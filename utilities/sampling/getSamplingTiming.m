function [frameTimesSec, samplingTRMs, meta] = getSamplingTiming(app, nGTFrames)
%GETSAMPLINGTIMING Build GT frame times and the sampling TR used for k-space.
%   SR-GRE GT can contain 168 sub-frames for each app.timing sample.  In
%   that case, expand every app.timing entry by 168 local frame offsets and
%   use the local GT frame spacing as the effective sampling TR.

if nargin < 2 || isempty(nGTFrames)
    nGTFrames = [];
end

explicitFrameTimesSec = [];
if hasAppProperty(app,'gtFrameTimesSec') && ~isempty(app.gtFrameTimesSec)
    explicitFrameTimesSec = double(app.gtFrameTimesSec(:).');
end

baseTimingSec = [];
if hasAppProperty(app,'timing') && ~isempty(app.timing)
    baseTimingSec = double(app.timing(:).');
end

framesPerTiming = getScalarProperty(app, 'gtFramesPerTiming', 168);
framesPerTiming = max(1, round(framesPerTiming));

frameTimeSec = [];
if hasAppProperty(app,'gtFrameTimeSec') && ~isempty(app.gtFrameTimeSec)
    frameTimeSec = double(app.gtFrameTimeSec);
end
if isempty(frameTimeSec) && hasAppProperty(app,'groundTruthFrameTimeSec') && ~isempty(app.groundTruthFrameTimeSec)
    frameTimeSec = double(app.groundTruthFrameTimeSec);
end
if isempty(frameTimeSec) && ~isempty(baseTimingSec) && framesPerTiming > 1 && numel(baseTimingSec) > 1
    frameTimeSec = median(diff(baseTimingSec)) / framesPerTiming;
end
if isempty(frameTimeSec)
    frameTimeSec = getTRMs(app) / 1000;
end

if isempty(nGTFrames)
    nGTFrames = inferGroundTruthFrameCount(app);
end
if isempty(nGTFrames) && ~isempty(baseTimingSec) && framesPerTiming > 1
    nGTFrames = numel(baseTimingSec) * framesPerTiming;
end

frameTimesSec = [];
expandedTiming = false;
if ~isempty(explicitFrameTimesSec)
    frameTimesSec = explicitFrameTimesSec;
    if isempty(nGTFrames)
        nGTFrames = numel(frameTimesSec);
    elseif nGTFrames < numel(frameTimesSec)
        frameTimesSec = frameTimesSec(1:nGTFrames);
    end
    expandedTiming = numel(frameTimesSec) ~= numel(baseTimingSec);
elseif ~isempty(baseTimingSec)
    if ~isempty(nGTFrames) && nGTFrames == numel(baseTimingSec) * framesPerTiming
        offsets = (0:framesPerTiming-1) * frameTimeSec;
        frameTimesSec = reshape((baseTimingSec(:) + offsets).', 1, []);
        expandedTiming = true;
    elseif ~isempty(nGTFrames) && nGTFrames ~= numel(baseTimingSec)
        frameTimesSec = baseTimingSec(1) + (0:nGTFrames-1) * frameTimeSec;
        expandedTiming = true;
    else
        frameTimesSec = baseTimingSec;
    end
elseif ~isempty(nGTFrames)
    frameTimesSec = (0:nGTFrames-1) * frameTimeSec;
end

samplingTRMs = [];
if hasAppProperty(app,'samplingTRMs') && ~isempty(app.samplingTRMs)
    samplingTRMs = double(app.samplingTRMs);
elseif hasAppProperty(app,'samplingTRSec') && ~isempty(app.samplingTRSec)
    samplingTRMs = double(app.samplingTRSec) * 1000;
elseif hasAppProperty(app,'gtFrameTimeSec') && ~isempty(app.gtFrameTimeSec)
    samplingTRMs = double(app.gtFrameTimeSec) * 1000;
elseif expandedTiming
    samplingTRMs = frameTimeSec * 1000;
else
    samplingTRMs = getTRMs(app);
end

meta = struct();
meta.baseTimingSec = baseTimingSec;
meta.explicitFrameTimesSec = explicitFrameTimesSec;
meta.frameTimesSec = frameTimesSec;
meta.frameTimeSec = frameTimeSec;
meta.framesPerTiming = framesPerTiming;
meta.expandedTiming = expandedTiming;
meta.nGTFrames = nGTFrames;
meta.samplingTRMs = samplingTRMs;
end

function value = getScalarProperty(app, propName, defaultValue)
value = defaultValue;
if hasAppProperty(app, propName) && ~isempty(app.(propName))
    value = double(app.(propName));
end
end

function trMs = getTRMs(app)
trMs = double(app.TR_sim.Value);
end

function nFrames = inferGroundTruthFrameCount(app)
nFrames = [];
if hasAppProperty(app,'gtNumFrames') && ~isempty(app.gtNumFrames)
    nFrames = double(app.gtNumFrames);
elseif hasAppProperty(app,'nGTFrames') && ~isempty(app.nGTFrames)
    nFrames = double(app.nGTFrames);
elseif hasAppProperty(app,'IMG_CP') && ~isempty(app.IMG_CP)
    nFrames = size(app.IMG_CP,4);
elseif hasAppProperty(app,'gtChunkDir') && ~isempty(app.gtChunkDir)
    nFrames = countChunkFrames(app.gtChunkDir);
end
end

function nFrames = countChunkFrames(gtChunkDir)
files = dir(fullfile(gtChunkDir,'gt_chunk_*.mat'));
if isempty(files)
    return
end
[~,idx] = sort({files.name});
files = files(idx);
nFrames = 0;
for c = 1:numel(files)
    chunkPath = fullfile(gtChunkDir,files(c).name);
    vars = whos('-file',chunkPath);
    names = {vars.name};
    gtIdx = strcmp(names,'GTchunk');
    if ~any(gtIdx)
        error('Missing GTchunk in %s', chunkPath);
    end
    gtSize = vars(gtIdx).size;
    if numel(gtSize) < 4
        gtSize(4) = 1;
    end
    if all(ismember({'fStart','fEnd'},names))
        s = load(chunkPath,'fStart','fEnd');
        nFrames = max(nFrames, double(s.fEnd));
    elseif all(ismember({'i1','i2'},names))
        s = load(chunkPath,'i1','i2');
        nFrames = max(nFrames, double(s.i2));
    else
        nFrames = nFrames + gtSize(4);
    end
end
end

function tf = hasAppProperty(app, propName)
if isstruct(app)
    tf = isfield(app, propName);
else
    tf = isprop(app, propName);
end
end
