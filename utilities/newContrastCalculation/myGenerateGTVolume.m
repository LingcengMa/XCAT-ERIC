
function IMG = myGenerateGTVolume(app, ro, state)
%MYGENERATEGTVOLUME Generate one GT volume for readout index ro.
% Memory-safe single-frame GT generator for chunked writing.
%
% Source priority:
% 1) app.IMG_CP (legacy in-memory 4D GT)
% 2) app.XCAT (single 3D label volume)
% 3) respiratory XCAT MAT series in a folder (default: utilities/XCAT_MAT_RESP)

% --- Path 1: legacy in-memory 4D GT ------------------------------------
if hasAppValue(app,'IMG_CP')
    vol4d = getAppValue(app,'IMG_CP');
    nFrames = size(vol4d,4);
    idx = min(max(1,round(double(ro))), nFrames);
    IMG = vol4d(:,:,:,idx);
    return
end

% --- Path 2: synthesize one frame from single XCAT volume --------------
if hasAppValue(app,'XCAT')
    XCAT = getAppValue(app,'XCAT');
    IMG = xcatToMrFrame(app, XCAT);
    return
end

% --- Path 3: synthesize from respiratory XCAT phase files --------------
xcatRespDir = '';
if hasAppValue(app,'xcatRespDir')
    xcatRespDir = getAppValue(app,'xcatRespDir');
elseif hasAppValue(app,'appPath')
    xcatRespDir = fullfile(getAppValue(app,'appPath'),'utilities','XCAT_MAT_RESP');
else
    xcatRespDir = fullfile(pwd,'utilities','XCAT_MAT_RESP');
end

if exist(xcatRespDir,'dir')
    files = dir(fullfile(xcatRespDir,'XCAT5D_RP_*_CP_*.mat'));
    if ~isempty(files)
        files = sortStructByName(files);
        rpIdx = mapReadoutToRespIndex(ro, numel(files), app, state);
        dat = load(fullfile(xcatRespDir, files(rpIdx).name));
        XCAT = firstVariable(dat);
        IMG = xcatToMrFrame(app, XCAT);
        return
    end
end

error(['myGenerateGTVolume: no source volume available. Provide app.IMG_CP, app.XCAT, ' ...
    'or XCAT respiratory files under utilities/XCAT_MAT_RESP (or app.xcatRespDir).']);
end


function IMG = xcatToMrFrame(app, XCAT)
FA = getOrDefault(app,'alpha_sim',8);
TR = getOrDefault(app,'TR_sim',3.0);
TE = getOrDefault(app,'TE_sim',1.5);
if hasAppValue(app,'ContrastDropDown')
    contrastName = app.ContrastDropDown.Value;
else
    contrastName = 'GRE';
end
b0 = getOrDefault(app,'B0',1.5);
fatFlag = false;

dyn = false;
enhanced_tissues = [];
C = [];
relaxivity = 0;

IMG = XCAT_to_MR_DCE(XCAT,FA,TR,TE,contrastName,b0,fatFlag,dyn,enhanced_tissues,C,relaxivity);
if ndims(IMG) == 4
    IMG = IMG(:,:,:,1);
end
end

function idx = mapReadoutToRespIndex(ro, nResp, app, state)
if nResp <= 1
    idx = 1;
    return
end

if hasAppValue(app,'kx_samples')
    nRO = size(getAppValue(app,'kx_samples'),2);
elseif hasAppValue(app,'timing')
    nRO = numel(getAppValue(app,'timing'));
else
    nRO = nResp;
end

% Use provided frame times if available, otherwise uniform mapping.
if nargin >= 4 && isstruct(state) && isfield(state,'frameTimesSec') && ~isempty(state.frameTimesSec)
    t = state.frameTimesSec;
    if numel(t) >= nResp
        ro = max(1,min(nRO,round(double(ro))));
        t_ro = (ro-1) / max(1,nRO-1) * (max(t)-min(t)) + min(t);
        [~,idx] = min(abs(t - t_ro));
        idx = max(1,min(nResp,idx));
        return
    end
end

idx = 1 + floor((max(1,min(nRO,round(double(ro))))-1) * nResp / max(1,nRO));
idx = max(1,min(nResp,idx));
end

function s = sortStructByName(s)
[~,ord] = sort({s.name});
s = s(ord);
end

function v = firstVariable(dat)
fns = fieldnames(dat);
if isempty(fns)
    error('Loaded MAT file contains no variables.');
end
v = dat.(fns{1});
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

function v = getAppValue(appObj, name)
if isobject(appObj) || isstruct(appObj)
    v = appObj.(name);
else
    error('Unsupported app container type: %s', class(appObj));
end
end

function val = getOrDefault(appObj, propName, defaultVal)
if hasAppValue(appObj, propName)
    p = getAppValue(appObj, propName);
    if isobject(p) && isprop(p,'Value')
        val = p.Value;
    else
        val = p;
    end
else
    val = defaultVal;
end
end
