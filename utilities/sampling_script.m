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
app.gtChunkDir = '/mnt/local_raid/lingcengma/XCAT_results/gt_chunks_test_copy_20260507';
app.framesPerChunk = 120;  % must match GT generation

% Enable streaming sampling
app.useStreaming = true;
app.allowLegacyIMGCP = false;

% Non-Cartesian stack-of-stars sampling
app.isCartesian = false;

% Folder containing thetas.txt, ky.txt, kz.txt
app.stackOfStarsTrajectoryDir = '/home/lingcengma/CODE/XCAT-ERIC';

% Your acquisition assumptions
app.stackOfStarsDiscardLines = 168;  % first 168 fixed startup k-space lines
app.stackOfStarsKzSamples = 44;      % 1.7 mm -> 4 mm kz downsampling

% Navigator after every 7 k-space acquisitions
app.navigatorEveryN = 7;
app.navigatorAfterKspace = false;

% Save sampling output in chunks
app.streamingChunkSize = 500;
app.keepFullStreamingInMemory = false;
app.streamingChunkDir = '/mnt/local_raid/lingcengma/XCAT_results/kspace_chunks_full';

% Optional final summary MAT
app.saveStreamingData = true;
app.streamingOutputPath = '/mnt/local_raid/lingcengma/XCAT_results/streaming_summary.mat';