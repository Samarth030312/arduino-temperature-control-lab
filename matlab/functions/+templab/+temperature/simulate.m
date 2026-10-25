function S = simulate(c)
%SIMULATE  Bulb-heated temperature loop, as the Arduino runs it.
%
%   S = templab.temperature.simulate(c)      c from defaultConfig / presetConfig
%
%   PLANT (ESTIMATED):  C dT/dt = eta P_bulb h(t) - (T - T_amb) / R_th
%   SENSOR: transport delay -> first-order lag -> DHT reading every 1 s (DHT11)
%           or 2 s (DHT22), quantised to its resolution, with noise.
%   CONTROLLER every Ts = 0.01 s (course), on the latest reading:
%     ONOFF / HYST / MA (on a moving average of the last N 10-ms samples) / P / TPROP /
%     STEP (full power until the reading reaches the setpoint, then off) / PI (clamping)
%     PID (D on each new sensor reading, filtered; simulation only) / OL (fixed power c.olPct %)
%   OPTIONS: c.Kd, c.uMaxPct (heater power limit, % of full), c.antiWindup (false: plain
%     integrator), c.ambStep (C) at c.tAmb (s): a step in the ambient temperature.
%   SSR: 'pwm490' -- a zero-cross SSR samples the 490 Hz PWM at the start of each
%        10 ms mains half-cycle, so the delivered power is a pseudo-random set of
%        half-cycles whose average is ~u/255 (this is the flicker the course asks
%        about); 'average' -- power = u/255 exactly.
%   SAFETY: heater forced off and latched when the reading reaches T_cutoff.
%
%   S (decimated to 0.1 s): t, sp, T, Tsens, Traw, Tfilt, e, u, heat (mean
%   on-fraction over 0.1 s), sw (cumulative switches); S.switches (heater on/off transitions, full rate),
%   S.metrics, S.cfg, S.units.

    P = c.P; dt = P.Ts;
    N = round(c.Tend / dt) + 1;
    is11 = strcmp(c.sensor, 'DHT11');
    per = P.per_dht22; res = P.res_dht22; tau = P.tau_dht22;
    if is11, per = P.per_dht11; res = P.res_dht11; tau = P.tau_dht11; end
    Tcut = P.T_cutoff; if ~is11 && isfield(P, 'T_cutoff_dht22'), Tcut = P.T_cutoff_dht22; end
    nPer = round(per / dt);
    nDel = max(1, round(P.delay / dt));
    rs = RandStream('mt19937ar', 'Seed', c.seed);

    dec = round(0.1 / dt); M = floor((N - 1) / dec) + 1;
    [tt, Tl, Tsl, Trl, Tfl, el, ul, hl, swl] = deal(nan(M, 1));

    T = P.T_amb; if isfield(c, 'T0') && isfinite(c.T0), T = c.T0; end    % c.T0: start warmer than the room
    Ts = T; Traw = NaN;
    delayBuf = repmat(T, nDel, 1); dp = 1;
    W = max(1, round(c.window)); maBuf = zeros(W, 1); maN = 0; maSum = 0; mp = 1;
    heatState = false; lastHeat = false; switches = 0; cutoff = false; stepDone = false; piI = 0;
    Kd = getf(c, 'Kd', 0); uTop = 255 * getf(c, 'uMaxPct', 100) / 100; aw = getf(c, 'antiWindup', true);
    ambStep = getf(c, 'ambStep', 0); tAmb = getf(c, 'tAmb', Inf); olPct = getf(c, 'olPct', 100);
    dTerm = 0; ePrevRd = NaN; newReading = false;
    TambL = nan(M, 1);
    hAcc = 0; nAcc = 0; m = 0; tReach = NaN;
    phase = 0.37;                                   % PWM vs mains phase, arbitrary

    for k = 1:N
        t = (k - 1) * dt;
        % ---------------------------------------------------- sensor
        Tdel = delayBuf(dp);
        Ts = Ts + dt / tau * (Tdel - Ts);
        newReading = mod(k - 1, nPer) == 0;
        if newReading
            Traw = round((Ts + P.noise * randn(rs)) / res) * res;
        end
        if isnan(tReach) && Traw >= c.setpoint - 0.5 && c.setpoint > 0, tReach = t; end
        % ---------------------------------------------------- filter (MA)
        maSum = maSum + Traw - maBuf(mp); maBuf(mp) = Traw; mp = mod(mp, W) + 1;
        maN = min(maN + 1, W);
        Tf = maSum / maN;
        % ---------------------------------------------------- controller
        u = NaN;
        switch c.mode
            case 'ONOFF', heatFrac = double(Traw < c.setpoint);
            case 'HYST'
                if Traw < c.setpoint - c.hyst / 2, heatState = true;
                elseif Traw > c.setpoint + c.hyst / 2, heatState = false; end
                heatFrac = double(heatState);
            case 'MA', heatFrac = double(Tf < c.setpoint);
            case 'STEP'
                if Traw >= c.setpoint, stepDone = true; end
                heatFrac = double(~stepDone);
            case 'OL'                                           % fixed heater power (open loop)
                u = round(255 * olPct / 100); heatFrac = u / 255;
            case {'P', 'TPROP', 'PI', 'PID'}
                e = c.setpoint - Traw;
                if strcmp(c.mode, 'PID') && newReading          % D on new readings only (DHT: 1 s)
                    if ~isnan(ePrevRd), dTerm = 0.5 * dTerm + 0.5 * Kd * (e - ePrevRd) / per; end
                    ePrevRd = e;
                end
                if any(strcmp(c.mode, {'PI', 'PID'}))           % same order as the firmware
                    dU = dTerm * strcmp(c.mode, 'PID');
                    iNew = piI + c.Ki * dt * e; uRaw = c.Kp * e + iNew + dU;
                    if ~aw || ~((uRaw > uTop && e > 0) || (uRaw < 0 && e < 0)), piI = iNew; end
                    u = min(max(round(c.Kp * e + piI + dU), 0), uTop);
                else
                    u = min(max(round(c.Kp * e), 0), uTop);
                end
                if strcmp(c.mode, 'TPROP')
                    heatFrac = double(mod(t, c.tprop) < u / 255 * c.tprop);
                elseif strcmp(c.ssr, 'average')
                    heatFrac = u / 255;
                else
                    heatFrac = double(mod(t * P.pwm_hz + phase, 1) < u / 255);
                end
            otherwise, error('templab:temperature:mode', 'unknown mode %s', c.mode);
        end
        if Traw >= Tcut, cutoff = true; end
        if cutoff, heatFrac = 0; end
        on = heatFrac > 0;
        if on ~= lastHeat && k > 1, switches = switches + 1; end
        lastHeat = on;
        if isnan(u), u = 255 * heatFrac; end
        % ---------------------------------------------------- plant
        Tamb = P.T_amb + ambStep * (t >= tAmb);
        T = T + dt / P.C_th * (P.eta_heat * P.P_bulb * heatFrac - (T - Tamb) / P.R_th);
        delayBuf(dp) = T; dp = mod(dp, nDel) + 1;
        % ---------------------------------------------------- log
        hAcc = hAcc + heatFrac; nAcc = nAcc + 1;
        if mod(k - 1, dec) == 0
            m = m + 1;
            tt(m) = t; Tl(m) = T; Tsl(m) = Ts; Trl(m) = Traw; Tfl(m) = Tf;
            el(m) = c.setpoint - Traw; ul(m) = u; hl(m) = hAcc / nAcc; hAcc = 0; nAcc = 0;
            swl(m) = switches; TambL(m) = Tamb;
        end
    end
    S = struct('t', tt(1:m), 'sp', repmat(c.setpoint, m, 1), 'T', Tl(1:m), 'Tsens', Tsl(1:m), ...
               'Traw', Trl(1:m), 'Tfilt', Tfl(1:m), 'e', el(1:m), 'u', ul(1:m), 'heat', hl(1:m), 'sw', swl(1:m), ...
               'switches', switches, 'cutoff', cutoff, 'tReach', tReach, 'Tamb', TambL(1:m), 'cfg', c);
    S.units = struct('temperature', 'degC', 'u', '0..255 (analogWrite)', 'heat', 'on-fraction');
    S.metrics = templab.temperature.metrics(S);
end

function v = getf(s, f, d)
    if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
