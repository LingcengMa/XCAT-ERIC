function manifestPath = writeGroundTruthManifest(app, outDir, nFrames, framesPerChunk, varargin)
%WRITEGROUNDTRUTHMANIFEST Save metadata needed to reload chunked GT previews.
% manifestPath = writeGroundTruthManifest(app, outDir, nFrames, framesPerChunk)
% writes gt_manifest.mat in outDir. The function is safe to call at the
% start of GT generation (nFrames = 0, manifestStatus = 'started') and again
% after chunk writing completes (manifestStatus = 'completed').

if nargin < 2
    error('writeGroundTruthManifest requires at least app and outDir.');
end
if nargin < 3 || isempty(nFrames)
    nFrames = inferGeneratedFrames(outDir);
end
if nargin < 4 || isempty(framesPerChunk)
    framesPerChunk = inferFramesPerChunk(outDir);
end
if ~exist(outDir,'dir')
    mkdir(outDir);
end

opts = parseNameValuePairs(varargin{:});
manifestPath = fullfile(outDir,'gt_manifest.mat');

if isfield(opts,'globalFrame')
    globalFrame = opts.globalFrame;
elseif isempty(nFrames)
    globalFrame = 0;
else
    globalFrame = nFrames;
end

if isfield(opts,'plannedFrames')
    plannedFrames = opts.plannedFrames;
else
    plannedFrames = [];
end

if isfield(opts,'manifestStatus')
    manifestStatus = opts.manifestStatus;
elseif ~isempty(plannedFrames) && globalFrame >= plannedFrames
    manifestStatus = 'completed';
elseif globalFrame > 0
    manifestStatus = 'partial';
else
    manifestStatus = 'started';
end

if isfield(opts,'outputSize')
    outputSize = opts.outputSize;
else
    outputSize = inferOutputSize(outDir);
end

timing = getOptionOrAppValue(opts, app, 'timing', []);
acqRes = getOptionOrDefault(opts, 'acqRes', getAcqRes(app));
TR = getOptionOrControl(opts, app, 'TR', 'TR_sim', []);
TE = getOptionOrControl(opts, app, 'TE', 'TE_sim', []);
FA = getOptionOrControl(opts, app, 'FA', 'alpha_sim', []);
b0 = getOptionOrControl(opts, app, 'b0', 'B0_sim_dropdown', []);
rel = getOptionOrControl(opts, app, 'rel', 'relaxivity', []);
contrast_time = getOptionOrControl(opts, app, 'contrast_time', 'injectionTime', []);
length_scan = getOptionOrDefault(opts, 'length_scan', getLengthScan(app));
DCE_temp = getOptionOrControl(opts, app, 'DCE_temp', 'contrastSamplingTime', []);
addResp = getOptionOrControl(opts, app, 'addResp', 'IncluderespiratorymotionCheckBox', []);
respPeriod = getOptionOrControl(opts, app, 'respPeriod', 'RespPeriod', []);
RespGT_waveform = getOptionOrAppValue(opts, app, 'RespGT_waveform', []);

save(manifestPath,'timing','acqRes','TR','TE','FA','b0','rel', ...
    'contrast_time','length_scan','DCE_temp','addResp','respPeriod', ...
    'RespGT_waveform','framesPerChunk','outputSize','globalFrame', ...
    'plannedFrames','manifestStatus','-v7.3');
end

function opts = parseNameValuePairs(varargin)
opts = struct();
if mod(numel(varargin),2) ~= 0
    error('Optional manifest metadata must be name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~ischar(name) && ~isstring(name)
        error('Manifest metadata names must be strings.');
    end
    opts.(char(name)) = varargin{k+1};
end
end

function value = getOptionOrDefault(opts, name, defaultValue)
if isfield(opts,name)
    value = opts.(name);
else
    value = defaultValue;
end
end

function value = getOptionOrAppValue(opts, appObj, name, defaultValue)
if isfield(opts,name)
    value = opts.(name);
elseif hasAppValue(appObj,name)
    value = appObj.(name);
else
    value = defaultValue;
end
end

function value = getOptionOrControl(opts, appObj, optionName, controlName, defaultValue)
if isfield(opts,optionName)
    value = opts.(optionName);
else
    value = getControlValue(appObj,controlName,defaultValue);
end
end

function acqRes = getAcqRes(appObj)
vals = {getControlValue(appObj,'anteriorposteriorRes',[]), ...
    getControlValue(appObj,'leftrightRes',[]), getControlValue(appObj,'footheadRes',[])};
if all(~cellfun(@isempty, vals))
    acqRes = [vals{:}];
else
    acqRes = [];
end
end

function length_scan = getLengthScan(appObj)
scanTimeMin = getControlValue(appObj,'scanTime',[]);
if isempty(scanTimeMin)
    length_scan = [];
else
    length_scan = scanTimeMin * 60;
end
end

function value = getControlValue(appObj, name, defaultValue)
value = defaultValue;
if ~hasAppValue(appObj,name)
    return
end
obj = appObj.(name);
if isobject(obj) && isprop(obj,'Value')
    value = obj.Value;
else
    value = obj;
end
end

function tf = hasAppValue(appObj, name)
if isobject(appObj)
    tf = isprop(appObj,name) && ~isempty(appObj.(name));
elseif isstruct(appObj)
    tf = isfield(appObj,name) && ~isempty(appObj.(name));
else
    tf = false;
end
end

function nFrames = inferGeneratedFrames(outDir)
chunkFiles = sortedChunkFiles(outDir);
nFrames = [];
if isempty(chunkFiles)
    return
end
lastChunk = fullfile(chunkFiles(end).folder, chunkFiles(end).name);
meta = load(lastChunk);
if isfield(meta,'i2')
    nFrames = meta.i2;
elseif isfield(meta,'fEnd')
    nFrames = meta.fEnd;
elseif isfield(meta,'GTchunk')
    nFrames = 0;
    for k = 1:numel(chunkFiles)
        info = whos('-file', fullfile(chunkFiles(k).folder, chunkFiles(k).name), 'GTchunk');
        if ~isempty(info) && numel(info.size) >= 4
            nFrames = nFrames + info.size(4);
        end
    end
end
end

function framesPerChunk = inferFramesPerChunk(outDir)
chunkFiles = sortedChunkFiles(outDir);
framesPerChunk = [];
if isempty(chunkFiles)
    return
end
info = whos('-file', fullfile(chunkFiles(1).folder, chunkFiles(1).name), 'GTchunk');
if ~isempty(info) && numel(info.size) >= 4
    framesPerChunk = info.size(4);
end
end

function outputSize = inferOutputSize(outDir)
chunkFiles = sortedChunkFiles(outDir);
if isempty(chunkFiles)
    outputSize = [];
    return
end
info = whos('-file', fullfile(chunkFiles(1).folder, chunkFiles(1).name), 'GTchunk');
if isempty(info)
    outputSize = [];
    return
end
outputSize = info.size(1:min(3,numel(info.size)));
end

function chunkFiles = sortedChunkFiles(outDir)
chunkFiles = dir(fullfile(outDir,'gt_chunk_*.mat'));
if isempty(chunkFiles)
    return
end
[~,idx] = sort({chunkFiles.name});
chunkFiles = chunkFiles(idx);
end
