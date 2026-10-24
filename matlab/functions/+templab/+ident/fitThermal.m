function m = fitThermal(t, y, u, Tamb)
%FITTHERMAL  K, tau, theta of a heater from a whole record (heating and cooling together).
%
%   m = templab.ident.fitThermal(t, y, u)            % u: heater share 0..1; Tamb = y(1)
%   m = templab.ident.fitThermal(t, y, u, Tamb)
%
%   Fits the first-order heat balance with dead time,  tau dT/dt = K u(t - theta) - (T - Tamb),
%   by least squares on the smoothed derivative, for every theta on a 1 s grid (0-120 s) and
%   keeps the best. It uses the heating AND the cooling parts, so it works on a curve that
%   was stopped before the steady state (the course's "bulb on until 55 C, then off"),
%   where a step-response fit has to guess the final value.
%   m.K (C at full power), m.tau (s), m.theta (s), m.rmse (C, model vs reading).
    t = t(:); y = y(:); u = u(:);
    ok = isfinite(t) & isfinite(y) & isfinite(u); t = t(ok); y = y(ok); u = u(ok);
    m = struct('K', NaN, 'tau', NaN, 'theta', NaN, 'rmse', NaN);
    if numel(t) < 20 || t(end) - t(1) < 30, return; end
    if nargin < 4, Tamb = y(1); end
    dt = median(diff(t));
    w = max(3, round(15 / dt));                                   % 15 s smoothing (DHT11: 1 C steps)
    ys = movmean(y, w);
    dy = gradient(ys, t);
    best = Inf;
    for th = 0:1:min(120, (t(end) - t(1)) / 3)
        ud = interp1(t, u, t - th, 'previous', 0);
        X = [ud, -(ys - Tamb)];
        keep = (1:numel(t))' > w & (1:numel(t))' < numel(t) - w;
        if nnz(keep) < 10, continue; end
        p = X(keep, :) \ dy(keep);                               % dy = (K/tau) u - (1/tau)(T - Tamb)
        if p(2) <= 0, continue; end
        e = norm(X(keep, :) * p - dy(keep));
        if e < best, best = e; m.tau = 1 / p(2); m.K = p(1) / p(2); m.theta = th; end
    end
    if isfinite(m.tau)                                           % model vs reading, for the record
        ud = interp1(t, u, t - m.theta, 'previous', 0); Tm = zeros(size(t)); Tm(1) = y(1);
        for k = 2:numel(t), Tm(k) = Tm(k - 1) + (t(k) - t(k - 1)) / m.tau * (m.K * ud(k - 1) - (Tm(k - 1) - Tamb)); end
        m.rmse = sqrt(mean((Tm - y).^2));
    end
end
