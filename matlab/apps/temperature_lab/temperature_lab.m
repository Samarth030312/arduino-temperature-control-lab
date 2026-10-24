function app = temperature_lab()
%TEMPLAB_TEMP  Temperature control: mission control for the bulb rig and its model.
%
%   cd <repo>/matlab; setup temperature        (or: run('setup_path.m'); temperature_lab)
%
%   Missions follow the TEMP handout: the heating curve (K, tau, theta), on-off at 35 / 45 /
%   55 C, hysteresis, the moving-average filter, P control, PI / PID, an ambient
%   disturbance, and the heater power limit with and without anti-windup; LAB is free use.
%
%   SIMULATE  templab.temperature.simulate: C dT/dt = eta P_el u - (T - T_amb)/R_th with the
%             transport delay, the DHT11's lag, 1 s update and 1 C steps, the 10 ms control
%             loop, and the zero-cross SSR driven by 490 Hz PWM. The thermal constants come
%             from the bulb, enclosure and sensor values in the physics panel
%             (templab.temperature.physics).
%   RIG       the same settings on the Arduino (temperature_controller, protocol $TTEL).
%             Every rig run is saved and registered (data/RUN_REGISTER.csv).
%   Safety: ABORT, Esc, Space switch the bulb off; the firmware switches it off if MATLAB is
%   silent for 3 s and latches it off at the over-temperature cut-off.
    D = struct();
    D.code = 'TEMP'; D.title = 'TEMPERATURE LAB'; D.tel = 'TTEL'; D.helloName = 'temperature_lab';
    D.welcome = 'Simulation of the bulb heater from the physics panel. Pick a mission; plug in the Uno to run it on the rig.';
    D.modeKey = 'mode'; D.spKey = 'setpoint'; D.tendKey = 'Tend';
    D.rigModes = {'ONOFF', 'HYST', 'MA', 'P', 'TPROP', 'STEP', 'PI'};
    D.yLabel = 'TEMPERATURE  (°C, what the DHT11 reads)'; D.uLabel = 'HEATER POWER  (% of full, mean over 0.1 s)';
    D.extraName = 'true zone T'; D.yPad = 2; D.playSpeed = '30x';
    D.physicsSection = 'BULB · ENCLOSURE · SENSOR  (→ physics)';
    D.sections = {'CONTROLLER', 'DISTURBANCE', D.physicsSection};
    D.controls = controls();
    D.missions = missions();
    D.physics = @physics;
    D.simulate = @simulate;
    D.extraTrace = @(S) deal(S.t, S.T);
    D.numbers = {'TEMPERATURE  °C', 'cyan', @(st) sprintf('%5.1f', st.y); ...
                 'SETPOINT  °C', 'text', @(st) sprintf('%5.1f', st.sp); ...
                 'HEATER  %', 'orange', @(st) sprintf('%5.0f', st.u); ...
                 'ERROR  °C', 'text', @(st) sprintf('%+5.1f', st.sp - st.y)};
    D.metrics = @metrics; D.rows = rows(); D.ref = @ref;
    D.scene = @(ax) templab.ui.tempRig(ax);
    D.pose = @pose;
    D.cfg = @(v) {v.mode, v.setpoint, v.hyst, round(v.window), v.Kp, round(1000 * v.tprop), v.Ki};
    D.defines = @(v) [{['DHT_KIND=' v.sensor]}, repmat({'LCD_I2C'}, 1, strcmp(v.lcd, 'i2c'))];
    D.fromTel = @fromTel;
    D.simulink = @openSimulink;
    app = templab.ui.missionControl(D);
end

% ======================================================================= definition
function C = controls()
    C = struct('key', {}, 'label', {}, 'section', {}, 'type', {}, 'lims', {}, 'fmt', {}, 'items', {}, ...
               'data', {}, 'default', {}, 'show', {}, 'tip', {});
    isMode = @(varargin) @(v) any(strcmp(v.mode, varargin));
    C(end + 1) = d('mode', 'law', 'CONTROLLER', {'open loop (fixed power)', 'heater step (heating curve)', 'on-off', ...
        'on-off + hysteresis', 'on-off on a moving average', 'P', 'P, time-proportioning SSR', 'PI', 'PID (simulation)'}, ...
        {'OL', 'STEP', 'ONOFF', 'HYST', 'MA', 'P', 'TPROP', 'PI', 'PID'}, 'ONOFF', [], '');
    C(end + 1) = n('setpoint', 'setpoint (°C)', 'CONTROLLER', [15 70], '%.1f', 45, isMode('STEP', 'ONOFF', 'HYST', 'MA', 'P', 'TPROP', 'PI', 'PID'), ...
        'Course: 35, 45 and 55 C. The firmware caps it 5 C under its cut-off.');
    C(end + 1) = n('olPct', 'heater power (%)', 'CONTROLLER', [0 100], '%.0f', 100, isMode('OL'), 'Open loop: a fixed share of full power');
    C(end + 1) = n('hyst', 'hysteresis band (°C, full)', 'CONTROLLER', [0 10], '%.1f', 1, isMode('HYST'), 'On below SP - band/2, off above SP + band/2');
    C(end + 1) = n('window', 'moving-average window N', 'CONTROLLER', [1 500], '%.0f', 10, isMode('MA'), 'Samples at Ts = 0.01 s (course: 10 and 500)');
    C(end + 1) = n('Kp', 'Kp  (counts / °C)', 'CONTROLLER', [0 1000], '%.1f', 50, isMode('P', 'TPROP', 'PI', 'PID'), 'Controller output 0-255 = analogWrite counts');
    C(end + 1) = n('Ki', 'Ki  (counts / °C·s)', 'CONTROLLER', [0 50], '%.3f', 0.5, isMode('PI', 'PID'), '');
    C(end + 1) = n('Kd', 'Kd  (counts·s / °C)', 'CONTROLLER', [0 5000], '%.0f', 200, isMode('PID'), 'D on each new sensor reading (DHT11: 1 s), filtered');
    C(end + 1) = n('tprop', 'time-proportioning window (s)', 'CONTROLLER', [0.2 60], '%.1f', 2, isMode('TPROP'), '');
    C(end + 1) = n('uMaxPct', 'heater power limit (%)', 'CONTROLLER', [5 100], '%.0f', 100, isMode('P', 'TPROP', 'PI', 'PID'), ...
        'Saturation: the controller output is clipped to this share of 255');
    C(end + 1) = d('aw', 'integrator', 'CONTROLLER', {'clamping anti-windup (firmware)', 'plain integrator (simulation)'}, {'on', 'off'}, 'on', isMode('PI', 'PID'), '');
    C(end + 1) = d('sensor', 'sensor', 'CONTROLLER', {'DHT11 (lab)', 'DHT22'}, {'DHT11', 'DHT22'}, 'DHT11', [], '');
    C(end + 1) = d('ssr', 'SSR drive', 'CONTROLLER', {'zero-cross SSR on 490 Hz PWM (as wired)', 'ideal: power = u/255'}, {'pwm490', 'average'}, 'pwm490', isMode('P', 'PI', 'PID'), '');
    C(end + 1) = n('Tend', 'run length (s)', 'CONTROLLER', [10 7200], '%.0f', 900, [], '');
    C(end + 1) = d('lcd', 'LCD (firmware build)', 'CONTROLLER', {'parallel 16x2 (D12, D11, D5-D2)', 'I2C backpack (A4, A5)'}, ...
        {'parallel', 'i2c'}, 'parallel', [], 'Which LCD the bench has; FLASH FIRMWARE builds for it');
    C(end + 1) = n('ambStep', 'ambient step (°C)', 'DISTURBANCE', [-20 20], '%.1f', 0, [], 'A sudden change of the room temperature');
    C(end + 1) = n('tAmb', 'ambient step at t (s)', 'DISTURBANCE', [0 7200], '%.0f', 600, [], '');
    S = 'BULB · ENCLOSURE · SENSOR  (→ physics)';
    C(end + 1) = n('bulb_W', 'bulb rating (W)', S, [5 500], '%.0f', 60, [], 'From the bulb''s label (ASSUMED 60 W until read)');
    C(end + 1) = n('bulb_V', 'bulb rated voltage (V)', S, [6 260], '%.0f', 230, [], '');
    C(end + 1) = n('mains_V', 'supply voltage (V)', S, [0 260], '%.0f', 230, [], 'Power scales as (V / V_rated)^1.6 for a filament');
    C(end + 1) = n('eta', 'heat fraction η', S, [0.05 1], '%.2f', 0.9, [], '~0.9 incandescent / halogen, ~0.3 LED');
    C(end + 1) = n('box_L', 'zone length (m)', S, [0.05 2], '%.2f', 0.30, [], 'The air volume heated with the sensor');
    C(end + 1) = n('box_W', 'zone width (m)', S, [0.05 2], '%.2f', 0.30, [], '');
    C(end + 1) = n('box_H', 'zone height (m)', S, [0.05 2], '%.2f', 0.30, [], '');
    C(end + 1) = n('U', 'wall loss U (W/m²K)', S, [0.1 50], '%.2f', 1.85, [], '~1-2 cardboard or wood, ~4-6 thin plastic or metal');
    C(end + 1) = n('m_struct', 'structure mass (kg)', S, [0 10], '%.2f', 0.13, [], 'Holder and walls that heat with the air');
    C(end + 1) = n('c_struct', 'its specific heat (J/kgK)', S, [100 5000], '%.0f', 900, [], '~900 aluminium / plastics, ~1300 wood');
    C(end + 1) = n('T_amb', 'room temperature (°C)', S, [0 50], '%.1f', 30, [], '');
    C(end + 1) = n('theta', 'bulb → sensor delay θ (s)', S, [0 120], '%.1f', 3, [], '');
    C(end + 1) = n('tau_s', 'sensor lag (s)', S, [0.01 120], '%.1f', 10, [], 'DHT body in still air');

    function c = n(key, label, sec, lims, fmt, def, show, tip)
        c = struct('key', key, 'label', label, 'section', sec, 'type', 'num', 'lims', lims, 'fmt', fmt, ...
                   'items', [], 'data', [], 'default', def, 'show', show, 'tip', tip);
    end
    function c = d(key, label, sec, items, data, def, show, tip)
        c = struct('key', key, 'label', label, 'section', sec, 'type', 'drop', 'lims', [], 'fmt', '', ...
                   'items', {items}, 'data', {data}, 'default', def, 'show', show, 'tip', tip);
    end
end

function M = missions()
    M = struct('tag', {}, 'short', {}, 'brief', {}, 'presets', {});
    add('T1', 'Heating curve', 'The bulb fully on from room temperature, then off: read K, tau and theta from the curve, and compare heating with cooling.', ...
        {'heater step to 60 °C, then cool', struct('mode', 'STEP', 'setpoint', 60, 'Tend', 1800); ...
         'open loop at 100 %', struct('mode', 'OL', 'olPct', 100, 'Tend', 1200); ...
         'open loop at 50 %', struct('mode', 'OL', 'olPct', 50, 'Tend', 1200)});
    add('T2', 'On-off', 'The bulb on below the setpoint, off above. The temperature settles into a cycle; the bulb flickers.', ...
        {'on-off, 35 °C', struct('mode', 'ONOFF', 'setpoint', 35, 'Tend', 900); 'on-off, 45 °C', struct('mode', 'ONOFF', 'setpoint', 45, 'Tend', 900); ...
         'on-off, 55 °C', struct('mode', 'ONOFF', 'setpoint', 55, 'Tend', 1200)});
    add('T3', 'Hysteresis', 'Two switching points instead of one: fewer switches, a wider band.', ...
        {'hysteresis ±0.5 °C, 45 °C', struct('mode', 'HYST', 'hyst', 1, 'setpoint', 45, 'Tend', 900); ...
         'hysteresis ±1 °C, 45 °C', struct('mode', 'HYST', 'hyst', 2, 'setpoint', 45, 'Tend', 900); ...
         'hysteresis ±2 °C, 45 °C', struct('mode', 'HYST', 'hyst', 4, 'setpoint', 45, 'Tend', 900)});
    add('T4', 'Moving average', 'On-off on the mean of the last N readings (Ts = 10 ms): the window against flicker and delay.', ...
        {'N = 10, 45 °C', struct('mode', 'MA', 'window', 10, 'setpoint', 45, 'Tend', 900); ...
         'N = 500, 45 °C', struct('mode', 'MA', 'window', 500, 'setpoint', 45, 'Tend', 900)});
    add('T5', 'P control', 'u = Kp e, clipped to 0-255, on pin 9 into the SSR. Small Kp: an offset; large Kp: on-off again.', ...
        {'Kp 1, 45 °C', p(1); 'Kp 2, 45 °C', p(2); 'Kp 50, 45 °C', p(50); 'Kp 100, 45 °C', p(100); 'Kp 500, 45 °C', p(500); ...
         'Kp 50, time-proportioning, 45 °C', struct('mode', 'TPROP', 'Kp', 50, 'setpoint', 45, 'Tend', 900)});
    add('T6', 'PI and PID', 'Integral action removes the offset P leaves; D reacts to the trend.', ...
        {'PI Kp 50 Ki 0.5, 45 °C', struct('mode', 'PI', 'Kp', 50, 'Ki', 0.5, 'setpoint', 45, 'Tend', 900, 'uMaxPct', 100); ...
         'PID Kp 50 Ki 0.5 Kd 200, 45 °C', struct('mode', 'PID', 'Kp', 50, 'Ki', 0.5, 'Kd', 200, 'setpoint', 45, 'Tend', 900, 'uMaxPct', 100); ...
         'P Kp 50, 45 °C (for comparison)', p(50)});
    add('T7', 'Disturbance', 'The room cools by 5 °C at t = 600 s. Which controller brings the temperature back?', ...
        {'on-off', struct('mode', 'ONOFF', 'setpoint', 45, 'Tend', 1200, 'ambStep', -5, 'tAmb', 600); ...
         'P Kp 50', struct('mode', 'P', 'Kp', 50, 'setpoint', 45, 'Tend', 1200, 'ambStep', -5, 'tAmb', 600); ...
         'PI Kp 50 Ki 0.5', struct('mode', 'PI', 'Kp', 50, 'Ki', 0.5, 'setpoint', 45, 'Tend', 1200, 'ambStep', -5, 'tAmb', 600); ...
         'PID Kp 50 Ki 0.5 Kd 200', struct('mode', 'PID', 'Kp', 50, 'Ki', 0.5, 'Kd', 200, 'setpoint', 45, 'Tend', 1200, 'ambStep', -5, 'tAmb', 600)});
    add('T8', 'Saturation', 'The heater limited to 40 % of full power. With a plain integrator the error piles up while the heater is maxed out.', ...
        {'PI, limit 40 %, clamping', struct('mode', 'PI', 'Kp', 50, 'Ki', 0.5, 'setpoint', 45, 'uMaxPct', 40, 'aw', 'on', 'Tend', 1500); ...
         'PI, limit 40 %, plain integrator', struct('mode', 'PI', 'Kp', 50, 'Ki', 0.5, 'setpoint', 45, 'uMaxPct', 40, 'aw', 'off', 'Tend', 1500); ...
         'PID, limit 40 %, plain integrator', struct('mode', 'PID', 'Kp', 50, 'Ki', 0.5, 'Kd', 200, 'setpoint', 45, 'uMaxPct', 40, 'aw', 'off', 'Tend', 1500)});
    add('LAB', 'Free', 'Any law, any setpoint. On the rig the setpoint changes live while it runs.', ...
        {'on-off, 45 °C', struct('mode', 'ONOFF', 'setpoint', 45, 'Tend', 900, 'ambStep', 0); ...
         'PI, 45 °C', struct('mode', 'PI', 'Kp', 50, 'Ki', 0.5, 'setpoint', 45, 'Tend', 900, 'ambStep', 0)});
    function s = p(Kp), s = struct('mode', 'P', 'Kp', Kp, 'setpoint', 45, 'Tend', 900, 'uMaxPct', 100, 'ambStep', 0); end
    function add(tag, short, brief, pr)
        % every preset starts from the same complete settings, so nothing leaks between them
        base = struct('mode', 'ONOFF', 'setpoint', 45, 'Tend', 900, 'olPct', 100, 'hyst', 1, 'window', 10, ...
            'Kp', 50, 'Ki', 0.5, 'Kd', 200, 'tprop', 2, 'uMaxPct', 100, 'aw', 'on', 'ambStep', 0, 'tAmb', 600);
        for i = 1:size(pr, 1)
            sv = base; f = fieldnames(pr{i, 2});
            for j = 1:numel(f), sv.(f{j}) = pr{i, 2}.(f{j}); end
            pr{i, 2} = sv;
        end
        P = struct('label', pr(:, 1)', 'set', pr(:, 2)');
        M(end + 1) = struct('tag', tag, 'short', short, 'brief', brief, 'presets', P);
    end
end

function R = rows()
    R = {'reach', 'time to the setpoint (s)', '%.0f'; 'over', 'overshoot (°C)', '%.1f'; ...
         'settle', 'settling, ±1 °C (s)', '%.0f'; 'ess', 'steady error (°C)', '%.2f'; ...
         'ripple', 'ripple, peak to peak (°C)', '%.1f'; 'swpm', 'bulb switches per minute', '%.1f'; ...
         'power', 'mean heater power (%)', '%.0f'; 'K', 'K: rise at full power (°C)', '%.1f'; ...
         'tau', 'τ (s)', '%.0f'; 'theta', 'θ, dead time (s)', '%.0f'; 'recov', 'back within 1 °C after the room step (s)', '%.0f'};
end

% ======================================================================= physics and simulation
function [P, txt] = physics(v)
    spec = struct('bulb_W', v.bulb_W, 'bulb_V', v.bulb_V, 'mains_V', v.mains_V, 'eta', v.eta, 'box_L', v.box_L, ...
        'box_W', v.box_W, 'box_H', v.box_H, 'U', v.U, 'm_struct', v.m_struct, 'c_struct', v.c_struct, ...
        'T_amb', v.T_amb, 'theta', v.theta, 'tau_s', v.tau_s);
    [P, D] = templab.temperature.physics(spec);
    P.derived = D;
    txt = sprintf(['P_el %.1f W   loss G = UA %.2f W/K\nR_th %.2f K/W   C %.0f J/K\nK %.1f °C (full power)\n' ...
        'τ = R C %.0f s   θ %.0f s   sensor %.0f s\nfull power: %.1f °C\n%s'], ...
        D.P_el, D.G, D.R_th, D.C, D.K, D.tau, D.theta, D.tau_s, D.T_max, D.tf);
end

function S = simulate(v, P)
    c = templab.temperature.defaultConfig();
    c.P = P; c.mode = v.mode; c.setpoint = v.setpoint; c.hyst = v.hyst; c.window = round(v.window);
    c.Kp = v.Kp; c.Ki = v.Ki; c.Kd = v.Kd; c.tprop = v.tprop; c.sensor = v.sensor; c.ssr = v.ssr;
    c.Tend = v.Tend; c.uMaxPct = v.uMaxPct; c.antiWindup = strcmp(v.aw, 'on');
    c.ambStep = v.ambStep; c.tAmb = v.tAmb; c.olPct = v.olPct;
    if strcmp(v.mode, 'OL'), c.setpoint = NaN; end
    R = templab.temperature.simulate(c);
    S = struct('t', R.t, 'y', R.Traw, 'ys', R.Traw, 'T', R.T, 'r', R.sp, 'u', 100 * R.heat, 'Tamb', R.Tamb, ...
               'switches', R.switches, 'cfg', c, 'Tmax', P.derived.T_max);
end

% ======================================================================= numbers
function m = metrics(t, r, y, u, v)
    m = struct();
    ok = isfinite(t) & isfinite(y); t = t(ok); y = y(ok); r = r(ok); u = u(ok);
    if numel(t) < 5, return; end
    sp = r(end); y0 = y(1);
    tail = t >= t(end) - 0.3 * (t(end) - t(1));
    m.power = mean(u, 'omitnan');
    on = u > 0; m.swpm = nnz(diff(on) ~= 0) / ((t(end) - t(1)) / 60);
    if any(strcmp(v.mode, {'OL', 'STEP'}))                     % the heating curve: K, tau, theta
        f = templab.ident.fitThermal(t, y, u / 100);
        m.K = f.K; m.tau = f.tau; m.theta = f.theta;
        if strcmp(v.mode, 'OL'), return; end
    end
    if ~isfinite(sp), return; end
    k = find(y >= sp - 0.5, 1);
    if ~isempty(k), m.reach = t(k) - t(1); m.over = max(0, max(y(k:end)) - sp); end
    A = sp - y0; if abs(A) > 0.5, yn = (y - y0) / A; end
    out = abs(y - sp) > 1;
    if ~out(end), j = find(out, 1, 'last'); if isempty(j), m.settle = 0; else, m.settle = t(j + 1) - t(1); end, end
    m.ess = sp - mean(y(tail)); m.ripple = max(y(tail)) - min(y(tail));
    if v.ambStep ~= 0 && v.tAmb < t(end)
        j = t >= v.tAmb; tt = t(j) - v.tAmb; yy = y(j); bad = abs(yy - sp) > 1;
        if ~bad(end), jl = find(bad, 1, 'last'); if isempty(jl), m.recov = 0; else, m.recov = tt(jl + 1); end, end
    end
end

function m = ref(v, P)
    % theory from the physics: the FOPDT constants; P's offset e = (r - T_amb)/(1 + K Kp/255);
    % on-off ripple ~ (heating + cooling rate at the setpoint) x the total delay
    D = P.derived; m = struct('K', D.K, 'tau', D.tau, 'theta', D.theta + D.tau_s);
    if ~isfinite(v.setpoint), return; end
    dT = v.setpoint - D.spec.T_amb;
    switch v.mode
        case 'P',   m.ess = dT / (1 + D.K * v.Kp / 255);
        case {'PI', 'PID'}, m.ess = 0;
        case {'ONOFF', 'MA', 'HYST'}
            thetaTot = D.theta + D.tau_s + 0.5;
            up = (D.K - dT) / D.tau; down = dT / D.tau;
            m.ripple = (up + down) * thetaTot + strcmp(v.mode, 'HYST') * v.hyst;
    end
end

% ======================================================================= scene, rig, Simulink
function pose(h, st)
    amb = 30; tmax = 85;
    if isfield(st, 'S'), amb = st.S.Tamb(st.k); tmax = st.S.Tmax; end
    templab.ui.tempRigPose(h, st.u, st.y, st.sp, amb, max(tmax, amb + 1));
end

function T = fromTel(Traw)
    % the firmware streams $TTEL all the time; a run is the frames with the RUNNING flag, and
    % their t_ms counts from the RUN command
    run = bitand(double(Traw.flags), 1) > 0;
    Traw = Traw(run, :);                         % idle frames (before RUN, after STOP) never count
    T = Traw;
    T.t_s = Traw.t_ms / 1000;
    T.meas = Traw.temp_raw;
    T.u_pct = 100 * Traw.u / 255;
end

function msg = openSimulink(v, P)
    here = fullfile(templab.repoRoot(), 'matlab', 'models', 'temperature');
    mdl = 'temperature_plant';
    c = templab.temperature.defaultConfig(); c.P = P;
    for f = {'mode', 'setpoint', 'hyst', 'Kp', 'Ki', 'Kd', 'sensor', 'Tend', 'uMaxPct', 'ambStep', 'tAmb', 'olPct'}
        if isfield(v, f{1}), c.(f{1}) = v.(f{1}); end
    end
    c.window = round(v.window); c.antiWindup = strcmp(v.aw, 'on');
    if ~isfile(fullfile(here, [mdl '.slx'])), build_temperature_simulink(here); end
    w = temperature_simulink_params(c);
    load_system(fullfile(here, [mdl '.slx']));
    set_param([mdl '/PI or PID'], 'AntiWindupMode', ternary(c.antiWindup, 'clamping', 'none'));
    mw = get_param(mdl, 'ModelWorkspace');
    for f = fieldnames(w)', assignin(mw, f{1}, w.(f{1})); end
    open_system(mdl);
    msg = sprintf('%s opened with these settings: press Run in Simulink.', mdl);
end

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
