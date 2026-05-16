function [traj, meta] = buildStackOfStarsTrajectory(app, thetaFile, kyFile, kzFile)
%BUILDSTACKOFSTARSTRAJECTORY Build stack-of-stars trajectory from ordering files.
%   [traj,meta] = buildStackOfStarsTrajectory(app,thetaFile,kyFile,kzFile)
%   reads the post-cutoff ordering files used by the reconstruction and
%   prepends fixed k-space lines for the discarded startup samples.
%
%   Required files:
%       thetaFile - spoke angles for k-space data (radians or degrees)
%       kyFile    - in-plane spoke/order index for k-space data
%       kzFile    - through-plane encoding order for k-space data
%
%   The generated trajectory has kx/ky golden-angle/radial spokes in-plane
%   and a down-sampled kz stack (default 44 acquired kz partitions) over the
%   current app.matrixFH reconstruction grid.

if nargin < 4
    error('buildStackOfStarsTrajectory requires thetaFile, kyFile, and kzFile.');
end

theta = readNumericVector(thetaFile);
kyOrder = readNumericVector(kyFile);
kzOrder = readNumericVector(kzFile);

nLines = max([numel(theta), numel(kyOrder), numel(kzOrder)]);
if numel(theta) ~= nLines
    theta = expandThetaByKyOrder(theta, kyOrder, nLines);
end
if numel(kyOrder) ~= nLines || numel(kzOrder) ~= nLines
    error('theta/ky/kz ordering lengths are inconsistent after theta expansion.');
end

theta = theta(:).';
kyOrder = kyOrder(:).';
kzOrder = kzOrder(:).';
if max(abs(theta)) > 2*pi
    theta = deg2rad(theta);
end

nDiscard = getAppScalar(app,'stackOfStarsDiscardLines',168);
if nDiscard > 0
    theta = [repmat(theta(1),1,nDiscard), theta];
    kyOrder = [repmat(kyOrder(1),1,nDiscard), kyOrder];
    kzOrder = [repmat(kzOrder(1),1,nDiscard), kzOrder];
end

nFE = size(app.kx_samples,1);
r = sqrt(app.kx_samples(:,1).^2 + app.ky_samples(:,1).^2);
if all(r == 0)
    r = linspace(-0.5,0.5,nFE).';
end

nReadouts = numel(theta);
kx = zeros(nFE,nReadouts,'like',app.kx_samples);
ky = zeros(nFE,nReadouts,'like',app.ky_samples);
for ro = 1:nReadouts
    kx(:,ro) = r .* cos(theta(ro));
    ky(:,ro) = r .* sin(theta(ro));
end

nAcqKz = getAppScalar(app,'stackOfStarsKzSamples',44);
kzLine = mapKzOrderToMatrix(kzOrder, nAcqKz, app.matrixFH);
kz = repmat(cast(kzLine(:).','like',app.kz_samples), nFE, 1);

traj = struct();
traj.kx = kx;
traj.ky = ky;
traj.kz = kz;
traj.theta = theta;
traj.kyOrder = kyOrder;
traj.kzOrder = kzOrder;
traj.isStackOfStars = true;
traj.navigatorAlongKz = true;
traj.kzConvention = 'centered';
traj.navKz = cast(linspace(-floor(app.matrixFH/2), ceil(app.matrixFH/2)-1, nFE).','like',app.kz_samples);
traj.navKx = zeros(nFE,1,'like',app.kx_samples);
traj.navKy = zeros(nFE,1,'like',app.ky_samples);

meta = struct();
meta.thetaFile = thetaFile;
meta.kyFile = kyFile;
meta.kzFile = kzFile;
meta.nReadoutsFromFiles = nLines;
meta.nDiscardPrepended = nDiscard;
meta.nReadouts = nReadouts;
meta.nFE = nFE;
meta.nAcqKz = nAcqKz;
meta.matrixFH = app.matrixFH;
end

function x = readNumericVector(path)
if ~exist(path,'file')
    error('Trajectory file not found: %s', path);
end
x = readmatrix(path);
x = x(:);
x = x(~isnan(x));
if isempty(x)
    error('Trajectory file is empty: %s', path);
end
end

function theta = expandThetaByKyOrder(theta, kyOrder, nLines)
if numel(kyOrder) ~= nLines
    error('Cannot expand theta: ky order length does not match expected line count.');
end
idx = round(kyOrder(:));
if min(idx) == 0
    idx = idx + 1;
end
if min(idx) < 1 || max(idx) > numel(theta)
    error('ky order cannot index theta table.');
end
theta = theta(idx);
end

function kzLine = mapKzOrderToMatrix(kzOrder, nAcqKz, matrixFH)
idx = round(kzOrder(:).');
if min(idx) == 0 && max(idx) <= nAcqKz-1
    idx = idx + 1;
end
if min(idx) >= 1 && max(idx) <= nAcqKz
    kzPositions = round(linspace(-floor(matrixFH/2), ceil(matrixFH/2)-1, nAcqKz));
    kzLine = kzPositions(idx);
else
    % Assume the file already stores centered matrix-FH kz coordinates.
    kzLine = kzOrder(:).';
end
end

function value = getAppScalar(app, propertyName, defaultValue)
value = defaultValue;
if isprop(app,propertyName) && ~isempty(app.(propertyName))
    value = app.(propertyName);
end
value = round(value(1));
end
