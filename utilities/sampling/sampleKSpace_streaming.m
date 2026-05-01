function [kspace, navigator] = sampleKSpace_streaming(app, isCartesian, SNR)
%SAMPLEKSPACE_STREAMING Stream readout-by-readout k-space generation.

warning('off','all')

FOV = [app.matrixAP app.matrixRL app.matrixFH];
nCh = 8;
Coils = Simulate_Coils(FOV,nCh);

load([app.appPath 'utilities/sampling/SliceProfile.mat']);
SP = SP';
if FOV(3) ~= 35
    SP = resample(SP,FOV(3),35);
    SP(round(FOV(3)/2+1:end)) = SP(floor(FOV(3)/2):-1:1);
end

nReadouts = size(app.kx_samples,2);
nFE = size(app.kx_samples,1);
kspace = complex(zeros(nFE,nReadouts,nCh,'single'));
navigator = complex(zeros(FOV(3),nReadouts,nCh,'single'));

traj = struct();
if ~isCartesian
    [traj.kx, traj.ky] = buildGoldenAngleTrajectory(app.kx_samples, app.ky_samples);
end

state = struct();
h = waitbar(0,'streaming k-space generation');
for ro = 1:nReadouts
    if mod(ro,50)==0 || ro==1
        waitbar(ro/nReadouts,h)
    end

    [IMG,state] = generateVolumeForReadout(app, ro, state);
    kspace(:,ro,:) = encodeOneReadout(IMG, app, ro, Coils, SP, isCartesian, traj);

    navLine = squeeze(mean(mean(Coils .* IMG,1),2));
    navigator(:,ro,:) = fftshift(fft(navLine,[],1),1);
end
close(h)

if SNR < 100
    NOISE = (1/SNR) * randn(size(kspace),'single') .* exp(1i*2*pi*rand(size(kspace),'single'));
    kspace = kspace + NOISE;
end

