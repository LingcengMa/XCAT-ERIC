TRsec = 0.006;  % 6 ms
chunkDir='/home/lingcengma/Data/XCAT_results/kspace_chunks_full/';
[kspace, navigator, navReadouts, navMeta] = readStreamingChunks(chunkDir);

% If your acquisition order is NAV then 7 k-space:
navEvery = 7;
nNav = numel(navReadouts);
navAcqIdx = navReadouts + (0:nNav-1);  % gives 1,9,17,... if navReadouts=1,8,15,...

tNav = (navAcqIdx - 1) * TRsec;

navSig = squeeze(abs(navigator(round(size(navigator,1)/2), :, 1)));

figure;
plot(tNav/60, navSig);
xlabel('Time (min)');
ylabel('|Navigator|');
grid on;