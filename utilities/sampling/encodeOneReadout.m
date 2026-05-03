function kout = encodeOneReadout(IMG, app, ro, Coils, SP, isCartesian, traj)
%ENCODEONEREADOUT Encode exactly one readout from one generated 3D volume.

if nargin < 7
    traj = struct();
end

FOV = size(IMG);
nCh = size(Coils,4);
nFE = size(app.kx_samples,1);

kout = complex(zeros(nFE,1,nCh,'single'));

sliceProfile = repmat(permute(SP,[2 3 1]), [FOV(1) FOV(2) 1]);

if isCartesian
    ky = round(app.ky_samples(1,ro));
    kz = round(app.kz_samples(1,ro));
    for coil = 1:nCh
        tmp = Coils(:,:,:,coil) .* IMG .* sliceProfile;
        K = fftshift(fftn(tmp,FOV));

        % Support both MATLAB-style 1-based indices and 0-based stored samples.
        if ky < 1 || kz < 1
            ky = ky + 1;
            kz = kz + 1;
        end
        kyUse = min(max(1,ky),size(K,1));
        kzUse = min(max(1,kz),size(K,3));

        kout(:,1,coil) = squeeze(K(kyUse,:,kzUse));
    end
else
    if isfield(traj,'kx')
        kx = traj.kx(:,ro);
        ky = traj.ky(:,ro);
    else
        kx = app.kx_samples(:,ro);
        ky = app.ky_samples(:,ro);
    end
    kz = app.kz_samples(:,ro);

    for coil = 1:nCh
        tmp = Coils(:,:,:,coil) .* IMG .* sliceProfile;
        kout(:,1,coil) = encodeOneNonCartesianReadout(tmp, kx, ky, kz, app);
    end
end


