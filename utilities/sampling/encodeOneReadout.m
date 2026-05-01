function kout = encodeOneReadout(IMG, app, ro, Coils, SP, isCartesian)
%ENCODEONEREADOUT Encode exactly one readout from one generated 3D volume.

FOV = size(IMG);
nCh = size(Coils,4);
nFE = size(app.kx_samples,1);

kout = complex(zeros(nFE,1,nCh,'single'));

sliceProfile = repmat(permute(SP,[2 3 1]), [FOV(1) FOV(2) 1]);

if isCartesian
    ky = app.ky_samples(1,ro);
    kz = app.kz_samples(1,ro);
    for coil = 1:nCh
        tmp = Coils(:,:,:,coil) .* IMG .* sliceProfile;
        K = fftshift(fftn(tmp,FOV));
        kout(:,1,coil) = squeeze(K(ky,:,kz));
    end
else
    kx = app.kx_samples(:,ro);
    ky = app.ky_samples(:,ro);
    kz = app.kz_samples(:,ro);
    for coil = 1:nCh
        tmp = Coils(:,:,:,coil) .* IMG .* sliceProfile;
        kout(:,1,coil) = encodeOneNonCartesianReadout(tmp, kx, ky, kz, app);
    end
end
