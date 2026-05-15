function [kspace, navigator, navReadouts] = sampleKSpace_streaming(app, isCartesian, SNR)
%SAMPLEKSPACE_STREAMING Stream readout-by-readout k-space generation.

warning('off','all')

FOV = [app.matrixAP app.matrixRL app.matrixFH];
nCh = 8;
Coils = Simulate_Coils(FOV,nCh);

load([app.appPath 'utilities/sampling/SliceProfile.mat']);
SP = SP';
if FOV(3) ~= 35
    SP = resample(SP,FOV(3),35);
    SP(round(FOV(3)/2+1:end)) = SP(floor(FOV(3)/2):-1:1);
end

traj = struct();
if ~isCartesian
    [useStackOfStars, thetaFile, kyFile, kzFile] = getStackOfStarsFiles(app);
    if useStackOfStars
        [traj, trajMeta] = buildStackOfStarsTrajectory(app, thetaFile, kyFile, kzFile);
    else
        [traj.kx, traj.ky] = buildGoldenAngleTrajectory(app.kx_samples, app.ky_samples);
        trajMeta = struct();
    end
else
    trajMeta = struct();
end

if isfield(traj,'kx')
    nReadouts = size(traj.kx,2);
    nFE = size(traj.kx,1);
else
    nReadouts = size(app.kx_samples,2);
    nFE = size(app.kx_samples,1);
end

% Optional chunked streaming to avoid holding full 4D-equivalent outputs in memory.
chunkSize = 0;
if isprop(app,'streamingChunkSize') && ~isempty(app.streamingChunkSize)
    chunkSize = max(0,round(app.streamingChunkSize));
end
keepFullInMemory = true;
if isprop(app,'keepFullStreamingInMemory')
    keepFullInMemory = logical(app.keepFullStreamingInMemory);
end
chunkDir = fullfile(app.appPath,'streaming_chunks');
if isprop(app,'streamingChunkDir') && ~isempty(app.streamingChunkDir)
    chunkDir = app.streamingChunkDir;
end
if chunkSize > 0
    if ~exist(chunkDir,'dir'); mkdir(chunkDir); end
    if ~keepFullInMemory
        kspace = [];
    else
        kspace = complex(zeros(nFE,nReadouts,nCh,'single'));
    end
else
    kspace = complex(zeros(nFE,nReadouts,nCh,'single'));
end

% Navigator cadence in k-space readouts, not total acquisitions.
% Set app.navigatorAfterKspace=false for NAV,K,K,K,K,K,K,K,NAV,...
% Set app.navigatorAfterKspace=true for K,K,K,K,K,K,K,NAV,K,...
navEvery = 1;
if isfield(traj,'isStackOfStars') && traj.isStackOfStars
    navEvery = 7;
end
if isprop(app,'navigatorEveryN') && ~isempty(app.navigatorEveryN)
    navEvery = max(1,round(app.navigatorEveryN));
end
navStartsAfterKspace = isfield(traj,'isStackOfStars') && traj.isStackOfStars;
if isprop(app,'navigatorAfterKspace') && ~isempty(app.navigatorAfterKspace)
    navStartsAfterKspace = logical(app.navigatorAfterKspace);
end
if navStartsAfterKspace
    navReadouts = navEvery:navEvery:nReadouts;
else
    navReadouts = 1:navEvery:nReadouts;
end
nNav = numel(navReadouts);
navAcquisitionIndices = zeros(1,nNav,'double');
if navStartsAfterKspace
    % K,K,K,K,K,K,K,NAV -> navReadouts 7,14,... -> acquisitions 8,16,...
    navAcquisitionIndices(:) = navReadouts + (1:nNav);
    kspaceAcquisitionIndices = (1:nReadouts) + floor(((1:nReadouts)-1)/navEvery);
else
    % NAV,K,K,K,K,K,K,K -> navReadouts 1,8,... -> acquisitions 1,9,...
    navAcquisitionIndices(:) = navReadouts + (0:nNav-1);
    kspaceAcquisitionIndices = (1:nReadouts) + floor(((1:nReadouts)-1)/navEvery) + 1;
end
[frameTimesSec, samplingTRMs, timingMeta] = getSamplingTiming(app, []);
if ~isempty(frameTimesSec) && isprop(app,'timing')
    app.timing = frameTimesSec;
end
if isprop(app,'samplingTRMs')
    app.samplingTRMs = samplingTRMs;
end
readoutTimesSec = ((kspaceAcquisitionIndices - 1) * samplingTRMs) / 1000;
navAcquisitionTimesSec = ((navAcquisitionIndices - 1) * samplingTRMs) / 1000;
navSamples = FOV(3);
if isfield(traj,'navigatorAlongKz') && traj.navigatorAlongKz
    navSamples = size(traj.navKz,1);
end
if chunkSize > 0 && ~keepFullInMemory
    navigator = [];
else
    navigator = complex(zeros(navSamples,nNav,nCh,'single'));
end

% Debug trajectory movie options
debugTrajectoryMovie = false;
recordTrajectoryFrames = false;
trajectoryMovieFormat = 'mp4'; % 'mp4' or 'gif'
trajectoryMoviePath = fullfile(app.appPath,'debug_trajectory.mp4');
if isprop(app,'debugTrajectoryMovie') && app.debugTrajectoryMovie
    debugTrajectoryMovie = true;
end
if isprop(app,'recordTrajectoryFrames') && app.recordTrajectoryFrames
    recordTrajectoryFrames = true;
end
if isprop(app,'trajectoryMovieFormat') && ~isempty(app.trajectoryMovieFormat)
    trajectoryMovieFormat = lower(app.trajectoryMovieFormat);
end
if isprop(app,'trajectoryMoviePath') && ~isempty(app.trajectoryMoviePath)
    trajectoryMoviePath = app.trajectoryMoviePath;
end

if debugTrajectoryMovie && ~isCartesian
    hTraj = figure('Name','Streaming trajectory debug','Color','w');
    axTraj = axes(hTraj);
    hold(axTraj,'on'); grid(axTraj,'on'); axis(axTraj,'equal');
    xlabel(axTraj,'k_x'); ylabel(axTraj,'k_y');
    title(axTraj,'Golden-angle spokes (streaming)');
    trajFrames = {};
end

state = struct();
if isprop(app,'volumeGenerator') && isa(app.volumeGenerator,'function_handle')
    state.volumeGenerator = app.volumeGenerator;
end
if isprop(app,'gtChunkDir') && ~isempty(app.gtChunkDir)
    state.gtChunkDir = app.gtChunkDir;
end
if isprop(app,'framesPerChunk') && ~isempty(app.framesPerChunk)
    state.framesPerChunk = app.framesPerChunk;
end
if isprop(app,'allowLegacyIMGCP')
    state.allowLegacyIMGCP = app.allowLegacyIMGCP;
end
if ~isempty(frameTimesSec)
    state.frameTimesSec = frameTimesSec;
end
state.samplingTRMs = samplingTRMs;
state.timingMeta = timingMeta;
state.nReadouts = nReadouts;
state.readoutTimesSec = readoutTimesSec;
h = waitbar(0,'streaming k-space generation');
navIdx = 1;
chunkStartRo = 1;
if chunkSize > 0
    chunkK = complex(zeros(nFE,chunkSize,nCh,'single'));
    chunkNav = complex(zeros(navSamples,chunkSize,nCh,'single'));
    chunkNavReadouts = zeros(1,chunkSize,'double');
    chunkNavAcquisitionIndices = zeros(1,chunkSize,'double');
    chunkCount = 0;
    chunkNavCount = 0;
    chunkId = 0;
end
for ro = 1:nReadouts
    if mod(ro,50)==0 || ro==1
        waitbar(ro/nReadouts,h)
    end

    [IMG,state] = generateVolumeForReadout(app, ro, state);
    roLine = encodeOneReadout(IMG, app, ro, Coils, SP, isCartesian, traj);
    if isempty(kspace)
        chunkCount = chunkCount + 1;
        chunkK(:,chunkCount,:) = roLine;
    else
        kspace(:,ro,:) = roLine;
        if chunkSize > 0
            chunkCount = chunkCount + 1;
            chunkK(:,chunkCount,:) = roLine;
        end
    end

    if navIdx <= nNav && ro == navReadouts(navIdx)
        if isfield(traj,'navigatorAlongKz') && traj.navigatorAlongKz
            navLineK = encodeNavigatorReadout(IMG, Coils, traj.navKz);
        else
            navLineK = encodeNavigatorReadout(IMG, Coils, []);
        end
        navLineK = reshape(navLineK, [size(navLineK,1), 1, nCh]);
        if isempty(navigator)
            chunkNavCount = chunkNavCount + 1;
            chunkNav(:,chunkNavCount,:) = navLineK;
            chunkNavReadouts(chunkNavCount) = ro;
            chunkNavAcquisitionIndices(chunkNavCount) = navAcquisitionIndices(navIdx);
        else
            navigator(:,navIdx,:) = navLineK;
            if chunkSize > 0
                chunkNavCount = chunkNavCount + 1;
                chunkNav(:,chunkNavCount,:) = navLineK;
                chunkNavReadouts(chunkNavCount) = ro;
                chunkNavAcquisitionIndices(chunkNavCount) = navAcquisitionIndices(navIdx);
            end
        end
        navIdx = navIdx + 1;
    end

    if debugTrajectoryMovie && ~isCartesian
        plot(axTraj, traj.kx(:,ro), traj.ky(:,ro), 'b-');
        title(axTraj, sprintf('Golden-angle spokes (streaming), RO=%d/%d', ro, nReadouts));
        drawnow limitrate
        if recordTrajectoryFrames
            fr = getframe(hTraj);
            trajFrames{end+1} = fr; %#ok<AGROW>
        end
    end

    if chunkSize > 0 && chunkCount == chunkSize
        chunkId = chunkId + 1;
        roRange = chunkStartRo:(chunkStartRo+chunkCount-1);
        chunkFile = fullfile(chunkDir,sprintf('stream_chunk_%04d.mat',chunkId));
        kspaceChunk = chunkK(:,1:chunkCount,:);
        navigatorChunk = chunkNav(:,1:chunkNavCount,:);
        navReadoutsChunk = chunkNavReadouts(1:chunkNavCount);
        navAcquisitionIndicesChunk = chunkNavAcquisitionIndices(1:chunkNavCount);
        navAcquisitionTimesSecChunk = ((navAcquisitionIndicesChunk - 1) * samplingTRMs) / 1000;
        kspaceAcquisitionIndicesChunk = kspaceAcquisitionIndices(roRange);
        readoutTimesSecChunk = readoutTimesSec(roRange);
        save(chunkFile,'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk','navAcquisitionIndicesChunk','navAcquisitionTimesSecChunk','kspaceAcquisitionIndicesChunk','readoutTimesSecChunk','samplingTRMs','-v7.3');
        chunkStartRo = ro + 1;
        chunkK(:) = 0; chunkNav(:) = 0; chunkNavReadouts(:) = 0; chunkNavAcquisitionIndices(:) = 0;
        chunkCount = 0; chunkNavCount = 0;
    end
end

if chunkSize > 0 && chunkCount > 0
    chunkId = chunkId + 1;
    roRange = chunkStartRo:(chunkStartRo+chunkCount-1);
    chunkFile = fullfile(chunkDir,sprintf('stream_chunk_%04d.mat',chunkId));
    kspaceChunk = chunkK(:,1:chunkCount,:);
    navigatorChunk = chunkNav(:,1:chunkNavCount,:);
    navReadoutsChunk = chunkNavReadouts(1:chunkNavCount);
    navAcquisitionIndicesChunk = chunkNavAcquisitionIndices(1:chunkNavCount);
    navAcquisitionTimesSecChunk = ((navAcquisitionIndicesChunk - 1) * samplingTRMs) / 1000;
    kspaceAcquisitionIndicesChunk = kspaceAcquisitionIndices(roRange);
    readoutTimesSecChunk = readoutTimesSec(roRange);
    save(chunkFile,'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk','navAcquisitionIndicesChunk','navAcquisitionTimesSecChunk','kspaceAcquisitionIndicesChunk','readoutTimesSecChunk','samplingTRMs','-v7.3');
end

close(h)

if SNR < 100
    NOISE_K = (1/SNR) * randn(size(kspace),'single') .* exp(1i*2*pi*rand(size(kspace),'single'));
    if ~isempty(kspace); kspace = kspace + NOISE_K; end

    NOISE_NAV = (1/SNR) * randn(size(navigator),'single') .* exp(1i*2*pi*rand(size(navigator),'single'));
    if ~isempty(navigator); navigator = navigator + NOISE_NAV; end
end

if debugTrajectoryMovie && ~isCartesian && recordTrajectoryFrames && ~isempty(trajFrames)
    switch trajectoryMovieFormat
        case 'gif'
            [outDir,~,~] = fileparts(trajectoryMoviePath);
            if isempty(outDir)
                trajectoryMoviePath = fullfile(app.appPath,'debug_trajectory.gif');
            end
            for i = 1:numel(trajFrames)
                [A,map] = rgb2ind(frame2im(trajFrames{i}),256);
                if i == 1
                    imwrite(A,map,trajectoryMoviePath,'gif','LoopCount',Inf,'DelayTime',0.05);
                else
                    imwrite(A,map,trajectoryMoviePath,'gif','WriteMode','append','DelayTime',0.05);
                end
            end
        otherwise
            if ~endsWith(lower(trajectoryMoviePath),'.mp4')
                trajectoryMoviePath = [trajectoryMoviePath '.mp4'];
            end
            vw = VideoWriter(trajectoryMoviePath,'MPEG-4');
            vw.FrameRate = 20;
            open(vw);
            for i = 1:numel(trajFrames)
                writeVideo(vw,trajFrames{i});
            end
            close(vw);
    end
end

% Optional in-app and on-disk persistence for downstream pipeline use.
if isprop(app,'kspace_streaming')
    app.kspace_streaming = kspace;
end
if isprop(app,'navigator_streaming')
    app.navigator_streaming = navigator;
end
if isprop(app,'navigatorReadouts_streaming')
    app.navigatorReadouts_streaming = navReadouts;
end
if isprop(app,'navigatorAcquisitionIndices_streaming')
    app.navigatorAcquisitionIndices_streaming = navAcquisitionIndices;
end
if isprop(app,'navigatorAcquisitionTimesSec_streaming')
    app.navigatorAcquisitionTimesSec_streaming = navAcquisitionTimesSec;
end
if isprop(app,'saveStreamingData') && app.saveStreamingData
    outPath = fullfile(app.appPath,'streaming_kspace_navigator.mat');
    if isprop(app,'streamingOutputPath') && ~isempty(app.streamingOutputPath)
        outPath = app.streamingOutputPath;
    end
    [outDir,~,~] = fileparts(outPath);
    if ~isempty(outDir) && ~exist(outDir,'dir')
        mkdir(outDir);
    end
    save(outPath,'kspace','navigator','navReadouts','navAcquisitionIndices','navAcquisitionTimesSec','kspaceAcquisitionIndices','readoutTimesSec','frameTimesSec','samplingTRMs','timingMeta','chunkDir','chunkSize','keepFullInMemory','trajMeta','-v7.3');
    disp(['Saved streaming k-space/navigator data to: ' outPath]);
    if chunkSize > 0
        disp(['Streaming chunk files were written to: ' chunkDir]);
    end
end
end

function [useStackOfStars, thetaFile, kyFile, kzFile] = getStackOfStarsFiles(app)
useStackOfStars = false;
thetaFile = '';
kyFile = '';
kzFile = '';
if isprop(app,'stackOfStarsTrajectoryDir') && ~isempty(app.stackOfStarsTrajectoryDir)
    trajDir = app.stackOfStarsTrajectoryDir;
    thetaFile = fullfile(trajDir,'thetas.txt');
    kyFile = fullfile(trajDir,'ky.txt');
    kzFile = fullfile(trajDir,'kz.txt');
    useStackOfStars = true;
end
if isprop(app,'stackOfStarsThetaFile') && ~isempty(app.stackOfStarsThetaFile)
    thetaFile = app.stackOfStarsThetaFile;
    useStackOfStars = true;
end
if isprop(app,'stackOfStarsKyFile') && ~isempty(app.stackOfStarsKyFile)
    kyFile = app.stackOfStarsKyFile;
    useStackOfStars = true;
end
if isprop(app,'stackOfStarsKzFile') && ~isempty(app.stackOfStarsKzFile)
    kzFile = app.stackOfStarsKzFile;
    useStackOfStars = true;
end
if useStackOfStars && (isempty(thetaFile) || isempty(kyFile) || isempty(kzFile))
    error('Stack-of-stars trajectory requires theta, ky, and kz files.');
end
end


function nFrames = countGroundTruthChunkFrames(gtChunkDir)
files = dir(fullfile(gtChunkDir,'gt_chunk_*.mat'));
if isempty(files)
    error('No gt_chunk_*.mat files found in: %s', gtChunkDir);
end
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




