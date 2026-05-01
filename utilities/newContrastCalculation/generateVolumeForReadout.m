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

% Backward-compatible mode: map readout to an existing contrast phase.
if isprop(app,'IMG_CP') && ~isempty(app.IMG_CP)
    nPhases = size(app.IMG_CP,4);
    nFE = size(app.kx_samples,2);
    readoutTiming = 0:app.TR_sim.Value:(nFE-1)*app.TR_sim.Value;
    sortedROs = sortReadOuts(nPhases, app.timing*1000, nFE, readoutTiming);
    phaseIdx = sortedROs(ro);
    phaseIdx = max(1,min(nPhases,phaseIdx));
    IMG = app.IMG_CP(:,:,:,phaseIdx);
else
    error(['No streaming ground-truth generator configured. ' ...
        'Set state.volumeGenerator or prepare app.IMG_CP for fallback mode.']);
end
