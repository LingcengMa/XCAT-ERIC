
%app.useGTChunkMode = true;
outDir = '/mnt/local_raid/lingcengma/XCAT_results';
framesPerChunk = 100;

% Optional manual override (set this before running if desired).
manualNReadouts = [];

% Robust nReadouts detection across app states.
if ~isempty(manualNReadouts)
    nReadouts = manualNReadouts;
elseif hasAppValue(app,'kx_samples')
    nReadouts = size(getAppValue(app,'kx_samples'),2);
elseif hasAppValue(app,'ky_samples')
    nReadouts = size(getAppValue(app,'ky_samples'),2);
elseif hasAppValue(app,'kz_samples')
    nReadouts = size(getAppValue(app,'kz_samples'),2);
elseif hasAppValue(app,'timing')
    nReadouts = numel(getAppValue(app,'timing'));
elseif hasAppValue(app,'IMG_CP')
    % Fallback if only legacy 4D GT is present.
    nReadouts = size(getAppValue(app,'IMG_CP'),4);
else
    error(['Unable to infer nReadouts. Set manualNReadouts in this script, or run trajectory ' ...
        'generation first so kx/ky/kz samples (or timing) are available.']);
end

if ~isscalar(nReadouts) || ~isfinite(nReadouts) || nReadouts < 1
    error('nReadouts must be a positive finite scalar.');
end
nReadouts = round(double(nReadouts));

if exist('myGenerateGTVolume','file') == 2
    volumeGenerator = @(app, ro, state) myGenerateGTVolume(app, ro, state);
elseif hasAppValue(app,'IMG_CP')
    % Legacy fallback: reuse already-generated in-memory GT frames.
    volumeGenerator = @(app, ro, state) getLegacyFrame(app, ro);
else
    error(['No GT generator available. Define myGenerateGTVolume.m on MATLAB path, ' ...
        'or populate app.IMG_CP before running this script.']);
end

manifestPath = writeGroundTruthManifest(app, outDir, 0, framesPerChunk, ...
    'plannedFrames', nReadouts, 'manifestStatus', 'started');
fprintf('Initialized GT manifest before chunk generation: %s\n', manifestPath);
writeGroundTruthChunks(app, outDir, nReadouts, framesPerChunk, volumeGenerator);
manifestPath = writeGroundTruthManifest(app, outDir, nReadouts, framesPerChunk, ...
    'plannedFrames', nReadouts, 'manifestStatus', 'completed');
fprintf('Finalized GT manifest after chunk generation: %s\n', manifestPath);

app.useStreaming = true;
app.gtChunkDir = outDir;
app.framesPerChunk = framesPerChunk;
app.allowLegacyIMGCP = false;

function tf = hasAppValue(appObj, name)
if isobject(appObj)
    tf = isprop(appObj,name) && ~isempty(appObj.(name));
elseif isstruct(appObj)
    tf = isfield(appObj,name) && ~isempty(appObj.(name));
else
    tf = false;
end
end

function v = getAppValue(appObj, name)
if isobject(appObj) || isstruct(appObj)
    v = appObj.(name);
else
    error('Unsupported app container type: %s', class(appObj));
end
end


function IMG = getLegacyFrame(appObj, ro)
vol4d = getAppValue(appObj,'IMG_CP');
nFrames = size(vol4d,4);
idx = min(max(1,round(double(ro))), nFrames);
IMG = vol4d(:,:,:,idx);
end