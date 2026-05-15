% Folder where sampleKSpace_streaming wrote stream_chunk_####.mat files
chunkDir = '/mnt/local_raid/lingcengma/XCAT_results/kspace_chunks_full';

% Reconstruct full arrays in memory
[kspace, navigator, navReadouts, meta] = readStreamingChunks(chunkDir);

fprintf('kspace size: [%s]\n', num2str(size(kspace)));
fprintf('navigator size: [%s]\n', num2str(size(navigator)));
fprintf('number of navigator readouts: %d\n', numel(navReadouts));

% Save one combined file if desired
save('/mnt/local_raid/lingcengma/XCAT_results/full_kspace_navigator.mat', ...
     'kspace','navigator','navReadouts','meta','-v7.3');

%%
chunkDir = '/mnt/local_raid/lingcengma/XCAT_results/kspace_chunks_full';

[kspace, navigator, navReadouts, navMeta] = readStreamingChunks(chunkDir);

% Use real navigator acquisition time if available
%tNav = navMeta.navAcquisitionTimesSec;

% Example navigator signal: magnitude at one kz sample and coil 1
navSig = squeeze(abs(navigator(round(size(navigator,1)/2), :, 1)));
tNav = navMeta.navAcquisitionTimesSec;
figure;
plot(tNav/60, navSig);
xlabel('Time (min)');
ylabel('|Navigator|');
title('Navigator vs real acquisition time');
grid on;