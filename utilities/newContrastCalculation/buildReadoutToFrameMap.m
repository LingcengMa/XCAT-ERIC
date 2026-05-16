function roToFrame = buildReadoutToFrameMap(nReadouts, trMs, frameTimesSec, readoutTimesSec)
%BUILDREADOUTTOFRAMEMAP Map readout index to nearest GT frame index.
%   roToFrame = buildReadoutToFrameMap(nReadouts,trMs,frameTimesSec)
%   assumes k-space readouts happen every TR.
%
%   roToFrame = buildReadoutToFrameMap(...,readoutTimesSec) uses explicit
%   acquisition times for each k-space readout. Use this when navigator
%   acquisitions consume TRs between k-space readouts.

if isempty(frameTimesSec)
    error('frameTimesSec is required to build readout->frame mapping.');
end

if nargin >= 4 && ~isempty(readoutTimesSec)
    readoutTimesSec = readoutTimesSec(:).';
    nReadouts = numel(readoutTimesSec);
else
    readoutTimesSec = ((0:nReadouts-1) * trMs) / 1000;
end

frameTimesSec = frameTimesSec(:).';
nFrames = numel(frameTimesSec);
roToFrame = ones(1,nReadouts);

for ro = 1:nReadouts
    [~,idx] = min(abs(frameTimesSec - readoutTimesSec(ro)));
    roToFrame(ro) = max(1,min(nFrames,idx));
end
end
