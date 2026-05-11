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

nReadouts = size(app.kx_samples,2);
nFE = size(app.kx_samples,1);

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

% Navigator sampling interval (default every readout). Set app.navigatorEveryN = 7
% to acquire one navigator every 7 k-space lines.
navEvery = 1;
if isprop(app,'navigatorEveryN') && ~isempty(app.navigatorEveryN)
    navEvery = max(1,round(app.navigatorEveryN));
end
navReadouts = 1:navEvery:nReadouts;
nNav = numel(navReadouts);
if chunkSize > 0 && ~keepFullInMemory
    navigator = [];
else
    navigator = complex(zeros(FOV(3),nNav,nCh,'single'));
end

traj = struct();
if ~isCartesian
    [traj.kx, traj.ky] = buildGoldenAngleTrajectory(app.kx_samples, app.ky_samples);
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
if isprop(app,'timing') && ~isempty(app.timing)
    state.frameTimesSec = app.timing;
end
h = waitbar(0,'streaming k-space generation');
navIdx = 1;
chunkStartRo = 1;
if chunkSize > 0
    chunkK = complex(zeros(nFE,chunkSize,nCh,'single'));
    chunkNav = complex(zeros(FOV(3),chunkSize,nCh,'single'));
    chunkNavReadouts = zeros(1,chunkSize,'double');
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
        navLine = squeeze(mean(mean(Coils .* IMG,1),2));
        navLineK = fftshift(fft(navLine,[],1),1);
        if isempty(navigator)
            chunkNavCount = chunkNavCount + 1;
            chunkNav(:,chunkNavCount,:) = navLineK;
            chunkNavReadouts(chunkNavCount) = ro;
        else
            navigator(:,navIdx,:) = navLineK;
            if chunkSize > 0
                chunkNavCount = chunkNavCount + 1;
                chunkNav(:,chunkNavCount,:) = navLineK;
                chunkNavReadouts(chunkNavCount) = ro;
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
        save(chunkFile,'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk','-v7.3');
        chunkStartRo = ro + 1;
        chunkK(:) = 0; chunkNav(:) = 0; chunkNavReadouts(:) = 0;
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
    save(chunkFile,'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk','-v7.3');
end
if chunkSize > 0
    streamManifestPath = fullfile(chunkDir,'stream_manifest.mat');
    nStreamChunks = chunkId;
    savedReadouts = nReadouts;
    savedChunkSize = chunkSize;
    savedKeepFullInMemory = keepFullInMemory;
    save(streamManifestPath,'nStreamChunks','savedReadouts','savedChunkSize', ...
        'savedKeepFullInMemory','navReadouts','-v7.3');
    fprintf('Saved streaming k-space chunks to: %s\n', chunkDir);
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
if isprop(app,'saveStreamingData') && app.saveStreamingData
    outPath = fullfile(app.appPath,'streaming_kspace_navigator.mat');
    if isprop(app,'streamingOutputPath') && ~isempty(app.streamingOutputPath)
        outPath = app.streamingOutputPath;
    end
    save(outPath,'kspace','navigator','navReadouts','-v7.3');
end

