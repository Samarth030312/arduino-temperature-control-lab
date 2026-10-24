function w = temperature_simulink_params(c)
%TEMPERATURE_SIMULINK_PARAMS  Model-workspace variables for temperature_plant.slx.
%   modes: ONOFF 1, HYST 2, MA 3, P 4, PI and PID 5, OL 6 (TPROP and STEP: MATLAB only).
%   The PID block's anti-windup is set with set_temperature_antiwindup(mdl, c).
    modes = struct('ONOFF', 1, 'HYST', 2, 'MA', 3, 'P', 4, 'PI', 5, 'PID', 5, 'OL', 6);
    assert(isfield(modes, c.mode), 'templab:simulink:mode', 'mode %s is not in the Simulink model (MATLAB only)', c.mode);
    P = c.P; is11 = strcmp(c.sensor, 'DHT11');
    w = struct('eta', P.eta_heat, 'Pbulb', P.P_bulb, 'Cth', P.C_th, 'Rth', P.R_th, 'Ta', P.T_amb, ...
        'delay', P.delay, 'Ts', P.Ts, 'SP', c.setpoint, 'hyst', c.hyst, 'N', c.window, 'Kp', c.Kp, ...
        'modeSel', modes.(c.mode), 'Tend', c.Tend);
    w.Ki = getf(c, 'Ki', 0) * any(strcmp(c.mode, {'PI', 'PID'}));
    w.Kd = getf(c, 'Kd', 0) * strcmp(c.mode, 'PID');
    w.uTop = 255 * getf(c, 'uMaxPct', 100) / 100;
    w.ambStep = getf(c, 'ambStep', 0); w.tAmb = min(getf(c, 'tAmb', 1e9), 1e9);
    w.olPct = getf(c, 'olPct', 100);
    if ~isfinite(w.SP), w.SP = 0; end
    if is11, w.tauS = P.tau_dht11; w.perDHT = P.per_dht11; w.resDHT = P.res_dht11;
    else,    w.tauS = P.tau_dht22; w.perDHT = P.per_dht22; w.resDHT = P.res_dht22; end
end

function v = getf(s, f, d)
    if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
