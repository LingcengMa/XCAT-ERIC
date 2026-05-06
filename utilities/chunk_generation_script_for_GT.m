app.useGTChunkMode = true;
app.gtChunkDir = fullfile(app.appPath,'gt_chunks_test');
app.framesPerChunk = 1;
app.gtMaxFrames = 1;
%%
app.useGTChunkMode = true;
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

volumeGenerator = @(app, ro, state) myGenerateGTVolume(app, ro, state);
writeGroundTruthChunks(app, outDir, nReadouts, framesPerChunk, volumeGenerator);

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