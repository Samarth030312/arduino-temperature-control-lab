function R = temperature_replay_runs(runIds, K, tau, theta, Ta, outName)
%TEMPERATURE_REPLAY_RUNS  Replay rig runs in the MATLAB simulator and in Simulink, against the rig.
%
%   R = temperature_replay_runs({'TEMP-R0006_...', ...}, K, tau, theta, Ta, 'name')
%
%   Each run is simulated with its own recorded settings (mode, setpoint, band, window, gains,
%   length) and its first reading as the start temperature, on the plant K (°C at full power),
%   tau (s), theta (s) with the room at Ta. The SSR is its average power in both simulators
%   (Simulink has no PWM / zero-cross model). Modes Simulink does not have (STEP, TPROP) are
%   simulated in MATLAB only. Columns: RMSE of the reading, rig against each simulator and the
%   two simulators against each other, all on the rig's 0.1 s time base.
%   Writes results/tables/<name>.csv when a name is given.
    rows = {};
    root = templab.repoRoot();
    tmp = tempname; mkdir(tmp); cl = onCleanup(@() rmdir(tmp, 's'));
    build_temperature_simulink(tmp);
    for i = 1:numel(runIds)
        id = runIds{i};
        T = readtable(fullfile(root, 'data', 'raw', 'temperature', [id '.csv']));
        J = jsondecode(fileread(fullfile(root, 'data', 'metadata', 'temperature', [id '.json'])));
        v = J.config_sent.values;
        c = templab.temperature.withFOPDT(templab.temperature.defaultConfig(), K, tau, theta);
        c.P.T_amb = Ta; c.P.noise = 0; c.ssr = 'average';
        for f = {'mode', 'setpoint', 'hyst', 'window', 'Kp', 'Ki', 'Kd', 'tprop'}
            if isfield(v, f{1}), c.(f{1}) = v.(f{1}); end
        end
        ok = isfinite(T.temp_raw); t = T.t_s(ok); y = T.temp_raw(ok);
        c.Tend = floor(t(end) * 10) / 10; c.T0 = y(1);
        k = t <= c.Tend; t = t(k); y = y(k);
        M = templab.temperature.simulate(c);
        yM = interp1(M.t, M.Traw, t, 'previous', 'extrap');
        rmse = @(a, b) sqrt(mean((a - b) .^ 2, 'omitnan'));
        eS = NaN; eMS = NaN; dutyS = NaN;
        if ~any(strcmp(c.mode, {'STEP', 'TPROP'}))
            S = run_temperature_simulink(c, tmp);
            yS = interp1(S.t, S.reading, t, 'previous', 'extrap');
            eS = rmse(y, yS); eMS = rmse(yM, yS); dutyS = mean(S.heat);
        end
        rows(end + 1, :) = {id, c.mode, c.setpoint, c.T0, c.Tend, rmse(y, yM), eS, eMS, ...
            mean(T.u(ok & T.t_s <= c.Tend)) / 255, mean(M.heat), dutyS}; %#ok<AGROW>
        fprintf('%-32s %-6s rig-MATLAB %.2f C  rig-Simulink %.2f C  MATLAB-Simulink %.3f C\n', id, c.mode, rows{end, 6:8});
    end
    R = cell2table(rows, 'VariableNames', {'run_id', 'mode', 'setpoint_C', 'T0_C', 'seconds', ...
        'rmse_rig_matlab_C', 'rmse_rig_simulink_C', 'rmse_matlab_simulink_C', 'power_rig', 'power_matlab', 'power_simulink'});
    if nargin >= 6 && ~isempty(outName)
        f = fullfile(root, 'results', 'tables', [outName '.csv']);
        if ~isfolder(fileparts(f)), mkdir(fileparts(f)); end
        writetable(R, f); fprintf('-> %s\n', f);
    end
end
