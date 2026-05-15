gtChunkDir = '/mnt/local_raid/lingcengma/XCAT_results/gt_chunks_test_copy_20260514';
[GT, gtFrameTimesSec, gtMeta] = readGroundTruthChunks(gtChunkDir, 2.016);

hold on;
yl = ylim;
for k = 1:numel(gtFrameTimesSec)
    xline(gtFrameTimesSec(k)/60, ':');
end
ylim(yl);

%%
save('/mnt/local_raid/lingcengma/XCAT_results/gt_chunks_test_copy_20260514/GT.mat','GT','-v7.3');