function [IMG, state] = generateVolumeForReadout(app, ro, state)
%GENERATEVOLUMEFORREADOUT Return one 3D ground-truth volume for readout ro.

if nargin < 3 || isempty(state)
    state = struct();
end

t_ms = (ro-1) * app.TR_sim.Value;
state.lastTimeMs = t_ms;

% Preferred mode: external callback that generates one volume on demand.
if isfield(state,'volumeGenerator') && isa(state.volumeGenerator,'function_handle')
    IMG = state.volumeGenerator(app, ro, state);
    return
end

% Disk-backed chunk mode for GT generation (no full 4D movie in memory).
% Each chunk file contains GTchunk(:,:,:,nLocal) indexed by frame number.
if isfield(state,'gtChunkDir') && ~isempty(state.gtChunkDir)
    if ~isfield(state,'framesPerChunk')
        error('state.framesPerChunk is required when using state.gtChunkDir.');
    end

    % Build readout->frame mapping once using frame times if provided.
    if ~isfield(state,'roToFrame')
        if isfield(state,'frameTimesSec')
            nReadouts = size(app.kx_samples,2);
            state.roToFrame = buildReadoutToFrameMap(nReadouts, app.TR_sim.Value, state.frameTimesSec);
        else
            state.roToFrame = 1:size(app.kx_samples,2);
        end
    end

    frameIdx = state.roToFrame(ro);
    chunkId = floor((frameIdx-1)/state.framesPerChunk) + 1;
    localIdx = mod(frameIdx-1, state.framesPerChunk) + 1;

    if ~isfield(state,'cachedChunkId') || state.cachedChunkId ~= chunkId
        chunkPath = fullfile(state.gtChunkDir, sprintf('gt_chunk_%04d.mat', chunkId));
        dat = load(chunkPath,'GTchunk');
        state.cachedChunk = dat.GTchunk;
        state.cachedChunkId = chunkId;
    end

    if localIdx > size(state.cachedChunk,4)
        error('Local frame index exceeds chunk size in %s', state.gtChunkDir);
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
    readoutTiming = 0:app.TR_sim.Value:(nFE-1)*app.TR_sim.Value;
    sortedROs = sortReadOuts(nPhases, app.timing*1000, nFE, readoutTiming);
    phaseIdx = sortedROs(ro);
    phaseIdx = max(1,min(nPhases,phaseIdx));
    IMG = app.IMG_CP(:,:,:,phaseIdx);
else
    error(['No streaming ground-truth generator configured. ' ...
        'Use state.volumeGenerator or state.gtChunkDir for chunked GT loading. ' ...
        'Legacy app.IMG_CP fallback is disabled by default.']);
end


