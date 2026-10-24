function m = metrics(S)
%METRICS  Temperature-run metrics: reach time, overshoot, band, error, flicker.
%
%   Steady window = last 30 % of the run. Flicker = heater on/off transitions
%   per minute over the whole run (each transition is a visible light change).
    c = S.cfg;
    m.t_reach = S.tReach;
    tail = S.t >= 0.7 * S.t(end);
    if isnan(S.tReach)
        m.overshoot = NaN;
    else
        m.overshoot = max(0, max(S.Traw(S.t >= S.tReach)) - c.setpoint);
    end
    m.band_pp = max(S.Traw(tail)) - min(S.Traw(tail));
    m.mean_error = c.setpoint - mean(S.Traw(tail));
    m.switches_per_min = S.switches / (S.t(end) / 60);
    m.duty = mean(S.heat);
    m.energy_Wh = c.P.P_bulb * sum(S.heat) * 0.1 / 3600;
    m.cutoff = S.cutoff;
    if S.cutoff
        m.verdict = 'OVER-TEMP CUT-OFF';
    elseif c.setpoint <= 0
        m.verdict = 'SENSOR ONLY';
    elseif isnan(S.tReach)
        m.verdict = 'NOT REACHED';
    elseif abs(m.mean_error) < 1 && m.band_pp <= 3
        m.verdict = 'REGULATING';
    elseif m.band_pp <= 3
        m.verdict = 'STEADY, OFFSET';
    else
        m.verdict = 'CYCLING';
    end
end
