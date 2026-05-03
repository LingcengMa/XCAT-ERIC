outDir = '/path/to/gt_chunks';
nReadouts = size(app.kx_samples,2);
framesPerChunk = 1200;

volumeGenerator = @(app, ro, state) myGenerateGTVolume(app, ro, state);
writeGroundTruthChunks(app, outDir, nReadouts, framesPerChunk, volumeGenerator);

app.useStreaming = true;
app.gtChunkDir = outDir;
app.framesPerChunk = framesPerChunk;
app.allowLegacyIMGCP = false;