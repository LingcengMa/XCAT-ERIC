function [kxGA, kyGA] = buildGoldenAngleTrajectory(kxBase, kyBase)
%BUILDGOLDENANGLETRAJECTORY Build golden-angle radial kx/ky from one base spoke.

nFE = size(kxBase,1);
nRO = size(kxBase,2);

% infer radial coordinate from first spoke in existing trajectory
r = sqrt(kxBase(:,1).^2 + kyBase(:,1).^2);
phi0 = atan2(kyBase(1,1), kxBase(1,1));
phiGA = pi * (3 - sqrt(5)); % 111.246... deg

kxGA = zeros(nFE,nRO,'like',kxBase);
kyGA = zeros(nFE,nRO,'like',kyBase);
for ro = 1:nRO
    phi = phi0 + (ro-1)*phiGA;
    kxGA(:,ro) = r .* cos(phi);
    kyGA(:,ro) = r .* sin(phi);
end

