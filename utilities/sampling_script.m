%%
app.sampleOnlyNoRecon = true;

%%
app.saveStreamingData = true;
app.streamingOutputPath = '/mnt/local_raid/lingcengma/XCAT_results/streaming_summary.mat';

app.streamingChunkSize = 500;
app.streamingChunkDir = '/mnt/local_raid/lingcengma/XCAT_results/kspace_chunks_full';
app.keepFullStreamingInMemory = false;
%%
% Use the GT chunks you already generated
app.gtChunkDir = '/mnt/local_raid/lingcengma/XCAT_results/gt_chunks_test_copy_20260514';
app.framesPerChunk = 168*4;  % must match GT generation

app.useStreaming = true;
app.allowLegacyIMGCP = false;
app.isCartesian = false;

% Old GT compatibility / SR-GRE local timing
app.gtFramesPerTiming = 168;
app.gtFrameTimeSec = 1.008 / 168;   % 0.006 sec
app.samplingTRMs = [];              % let getSamplingTiming derive 6 ms, or set 6 explicitly

% NAV then 7 k-space readouts
app.navigatorEveryN = 7;
app.navigatorAfterKspace = false;

% Stack-of-stars files
app.stackOfStarsTrajectoryDir = '/mnt/local_raid/lingcengma/XCAT_results/trajectory_files';
app.stackOfStarsDiscardLines = 168;
app.stackOfStarsKzSamples = 44;

% Save chunked sampling output
app.streamingChunkSize = 500;
app.keepFullStreamingInMemory = false;
app.streamingChunkDir = '/mnt/local_raid/lingcengma/XCAT_results/kspace_chunks_full';
app.saveStreamingData = true;
app.streamingOutputPath = '/mnt/local_raid/lingcengma/XCAT_results/streaming_summary.mat';