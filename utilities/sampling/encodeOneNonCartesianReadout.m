function kline = encodeOneNonCartesianReadout(IMGcoil, kx, ky, kz, app)
%ENCODEONENONCARTESIANREADOUT Encode one non-Cartesian readout using existing conventions.

x = kx * app.matrixRL;
y = ky * app.matrixAP;
z = kz - app.matrixFH/2;

kloc = cat(3,y,x,z);
kloc = permute(kloc, [3 1 2]);

tmp2 = fft(ifftshift(IMGcoil,3),[],3); % same as sampleKSpace.m

currSl = z(1);
kloc2 = kloc;
kloc2(3,:,:) = 0;
obj = nufft_3d(kloc2,[app.matrixAP app.matrixRL 1],'radial',1,'gpu',0);
slIdx = currSl + app.matrixFH/2 + 1;
kline = obj.fNUFT(squeeze(tmp2(:,:,slIdx)));
kline = reshape(kline, [], 1);
