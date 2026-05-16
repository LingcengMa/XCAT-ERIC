function [IMG, state] = generateVolumeForReadout(app, ro, state)
%GENERATEVOLUMEFORREADOUT Return one 3D ground-truth volume for readout ro.

if nargin < 3 || isempty(state)
    state = struct();
end

if isfield(state,'overrideTimeSec') && ~isempty(state.overrideTimeSec)
    t_ms = state.overrideTimeSec * 1000;
elseif isfield(state,'readoutTimesSec') && numel(state.readoutTimesSec) >= ro
    t_ms = state.readoutTimesSec(ro) * 1000;
else
    t_ms = (ro-1) * getStateTRMs(app, state);
end
state.lastTimeMs = t_ms;

% Preferred mode: external callback that generates one volume on demand.
if isfield(state,'volumeGenerator') && isa(state.volumeGenerator,'function_handle')
    IMG = state.volumeGenerator(app, ro, state);
    return
end

% Disk-backed chunk mode for GT generation (no full 4D movie in memory).
% Each chunk file contains GTchunk(:,:,:,nLocal) indexed by global frame.
if isfield(state,'gtChunkDir') && ~isempty(state.gtChunkDir)
    if ~isfield(state,'gtChunkIndex')
        state.gtChunkIndex = buildGTChunkIndex(state.gtChunkDir);
    end

    % Build readout->frame mapping once using frame times if provided.
    if ~isfield(state,'roToFrame')
        if isfield(state,'nReadouts') && ~isempty(state.nReadouts)
            nReadouts = state.nReadouts;
        else
            nReadouts = size(app.kx_samples,2);
        end
        if isfield(state,'frameTimesSec')
            readoutTimesSec = [];
            if isfield(state,'readoutTimesSec')
                readoutTimesSec = state.readoutTimesSec;
            end
            state.roToFrame = buildReadoutToFrameMap(nReadouts, getStateTRMs(app, state), state.frameTimesSec, readoutTimesSec);
        else
            state.roToFrame = 1:nReadouts;
        end
    end

    if isfield(state,'overrideTimeSec') && ~isempty(state.overrideTimeSec) && isfield(state,'frameTimesSec')
        [~,frameIdx] = min(abs(state.frameTimesSec - state.overrideTimeSec));
    else
        frameIdx = state.roToFrame(ro);
    end

    [chunkId, localIdx] = locateGTFrame(state.gtChunkIndex, frameIdx);
    if ~isfield(state,'cachedChunkId') || state.cachedChunkId ~= chunkId
        chunkPath = state.gtChunkIndex.files{chunkId};
        dat = load(chunkPath,'GTchunk');
        state.cachedChunk = dat.GTchunk;
        state.cachedChunkId = chunkId;
    end

    if localIdx > size(state.cachedChunk,4)
        error('Local frame index %d exceeds chunk %d size in %s', localIdx, chunkId, state.gtChunkDir);
    end
    IMG = state.cachedChunk(:,:,:,localIdx);
    return
end

% Backward-compatible mode: map readout to an existing contrast phase.
% NOTE: this path still relies on app.IMG_CP and therefore requires full
% 4D ground-truth in memory. Keep disabled unless explicitly allowed.
allowLegacy = false;
if isfield(state,'allowLegacyIMGCP')
    allowLegacy = logical(state.allowLegacyIMGCP);
end
if allowLegacy && isprop(app,'IMG_CP') && ~isempty(app.IMG_CP)
    nPhases = size(app.IMG_CP,4);
    nFE = size(app.kx_samples,2);
    [frameTimesSec, samplingTRMs] = getSamplingTiming(app, nPhases);
    readoutTiming = 0:samplingTRMs:(nFE-1)*samplingTRMs;
    sortedROs = sortReadOuts(nPhases, frameTimesSec*1000, nFE, readoutTiming);
    phaseIdx = sortedROs(ro);
    phaseIdx = max(1,min(nPhases,phaseIdx));
    IMG = app.IMG_CP(:,:,:,phaseIdx);
else
    error(['No streaming ground-truth generator configured. ' ...
        'Use state.volumeGenerator or state.gtChunkDir for chunked GT loading. ' ...
        'Legacy app.IMG_CP fallback is disabled by default.']);
end

function trMs = getStateTRMs(app, state)
if isfield(state,'samplingTRMs') && ~isempty(state.samplingTRMs)
    trMs = state.samplingTRMs;
else
    trMs = app.TR_sim.Value;
end
end

function index = buildGTChunkIndex(gtChunkDir)
files = dir(fullfile(gtChunkDir,'gt_chunk_*.mat'));
if isempty(files)
    error('generateVolumeForReadout:NoGTChunks', 'No gt_chunk_*.mat files found in: %s', gtChunkDir);
end
[~,ord] = sort({files.name});
files = files(ord);

frameRanges = zeros(numel(files),2);
filePaths = cell(1,numel(files));
nextStart = 1;
for c = 1:numel(files)
    chunkPath = fullfile(gtChunkDir,files(c).name);
    info = whos('-file',chunkPath);
    names = {info.name};
    gtInfo = info(strcmp(names,'GTchunk'));
    if isempty(gtInfo)
        error('generateVolumeForReadout:BadGTChunk', 'Missing GTchunk in %s', chunkPath);
    end
    gtSize = gtInfo.size;
    if numel(gtSize) < 4
        gtSize(4) = 1;
    end
    frameRanges(c,:) = readChunkFrameRange(chunkPath, names, nextStart, nextStart + gtSize(4) - 1);
    nextStart = frameRanges(c,2) + 1;
    filePaths{c} = chunkPath;
end

index = struct();
index.files = filePaths;
index.frameRanges = frameRanges;
index.nFrames = max(frameRanges(:,2));
end

function frameRange = readChunkFrameRange(chunkPath, names, fallbackStart, fallbackEnd)
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
end
function [chunkId, localIdx] = locateGTFrame(index, frameIdx)
frameIdx = double(frameIdx);
if frameIdx < 1 || frameIdx > index.nFrames
    error('generateVolumeForReadout:GTFrameOutOfRange', ...
        'Requested GT frame %d, but chunks only contain frames 1..%d.', frameIdx, index.nFrames);
end
chunkId = find(index.frameRanges(:,1) <= frameIdx & index.frameRanges(:,2) >= frameIdx, 1, 'first');
if isempty(chunkId)
    error('generateVolumeForReadout:MissingGTFrame', ...
        'Requested GT frame %d is not covered by any gt_chunk file.', frameIdx);
end
localIdx = frameIdx - index.frameRanges(chunkId,1) + 1;
end
