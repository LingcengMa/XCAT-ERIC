function roToFrame = buildReadoutToFrameMap(nReadouts, trMs, frameTimesSec)
%BUILDREADOUTTOFRAMEMAP Map readout index to nearest GT frame index.

if isempty(frameTimesSec)
    error('frameTimesSec is required to build readout->frame mapping.');
end

readoutTimesSec = ((0:nReadouts-1) * trMs) / 1000;
nFrames = numel(frameTimesSec);
roToFrame = ones(1,nReadouts);

for ro = 1:nReadouts
    [~,idx] = min(abs(frameTimesSec - readoutTimesSec(ro)));
    roToFrame(ro) = max(1,min(nFrames,idx));
end
