function [kspace, navigator, navReadouts, meta] = readStreamingChunks(chunkDir)
%READSTREAMINGCHUNKS Reassemble streaming k-space and navigator chunks.
%   [kspace,navigator,navReadouts,meta] = readStreamingChunks(chunkDir)
%   reads stream_chunk_####.mat files written by sampleKSpace_streaming and
%   concatenates them into full arrays.
%
%   Each chunk file is expected to contain:
%       kspaceChunk       [nFE nReadoutsInChunk nCh]
%       navigatorChunk    [nZ nNavInChunk nCh]
%       roRange           readout indices covered by kspaceChunk
%       navReadoutsChunk  readout indices covered by navigatorChunk
%
%   Outputs:
%       kspace       [nFE nReadouts nCh]
%       navigator    [nZ nNav nCh], packed by acquired navigator order
%       navReadouts  [1 nNav], readout indices corresponding to navigator
%       meta         struct with chunk file list and dimensions

if nargin < 1 || isempty(chunkDir)
    error('readStreamingChunks:MissingChunkDir', 'chunkDir is required.');
end
if ~exist(chunkDir,'dir')
    error('readStreamingChunks:MissingChunkDir', 'Chunk directory does not exist: %s', chunkDir);
end

files = dir(fullfile(chunkDir,'stream_chunk_*.mat'));
if isempty(files)
    error('readStreamingChunks:NoChunks', 'No stream_chunk_*.mat files found in: %s', chunkDir);
end
[~,idx] = sort({files.name});
files = files(idx);

% First pass: determine final output sizes.
nReadouts = 0;
nNav = 0;
nFE = [];
nCh = [];
nZ = [];
for c = 1:numel(files)
    chunkPath = fullfile(chunkDir,files(c).name);
    info = whos('-file',chunkPath);
    names = {info.name};
    required = {'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk'};
    if ~all(ismember(required,names))
        error('readStreamingChunks:BadChunk', 'Missing required variables in %s', chunkPath);
    end

    dat = load(chunkPath,'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk');
    if isempty(nFE)
        nFE = size(dat.kspaceChunk,1);
        nCh = size(dat.kspaceChunk,3);
        nZ = size(dat.navigatorChunk,1);
    end
    nReadouts = max(nReadouts,max(dat.roRange));
    nNav = nNav + numel(dat.navReadoutsChunk);
end

% Allocate full arrays. This intentionally reconstructs the full data in
% memory; use the original chunk files directly if the full array is too large.
first = load(fullfile(chunkDir,files(1).name),'kspaceChunk','navigatorChunk');
kspace = complex(zeros(nFE,nReadouts,nCh,'like',first.kspaceChunk));
navigator = complex(zeros(nZ,nNav,nCh,'like',first.navigatorChunk));
navReadouts = zeros(1,nNav,'double');

% Second pass: fill outputs.
navOffset = 0;
for c = 1:numel(files)
    chunkPath = fullfile(chunkDir,files(c).name);
    dat = load(chunkPath,'kspaceChunk','navigatorChunk','roRange','navReadoutsChunk');

    kspace(:,dat.roRange,:) = dat.kspaceChunk;

    nNavChunk = numel(dat.navReadoutsChunk);
    if nNavChunk > 0
        navIdx = navOffset + (1:nNavChunk);
        navigator(:,navIdx,:) = dat.navigatorChunk(:,1:nNavChunk,:);
        navReadouts(navIdx) = dat.navReadoutsChunk;
        navOffset = navOffset + nNavChunk;
    end
end

meta = struct();
meta.chunkDir = chunkDir;
meta.files = {files.name};
meta.nChunks = numel(files);
meta.nReadouts = nReadouts;
meta.nFE = nFE;
meta.nCh = nCh;
meta.nZ = nZ;
meta.nNav = nNav;
end
