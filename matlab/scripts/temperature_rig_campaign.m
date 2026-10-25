function R = temperature_rig_campaign(port, steps, varargin)
%TEMPERATURE_RIG_CAMPAIGN  The rig's experiments one after another, in the app, recorded.
%
%   R = temperature_rig_campaign('/dev/ttyUSB0')                  % every experiment the rig can run
%   R = temperature_rig_campaign('COM5', {'T2', 1; 'T5', 3})      % N x 2: mission, preset number
%   ... 'CoolTo', 30, 'CoolMax', 900      start each run below 30 C, waiting at most 900 s
%   ... 'Tend', 80, 'SpAbove', 3           short runs: 80 s each, setpoint 3 C above the reading
%                                          at the start of the run (default: as in the preset)
%
%   Opens temperature_lab, connects, and for each step selects the mission and preset and runs it
%   exactly as RUN ON RIG does: every run is saved and registered by the app. Before each run
%   the box cools until the reading is below CoolTo (default: the room temperature at the start
%   plus 6 C), so every run starts from about the same state. A firmware fault is logged,
%   cleared, and the campaign goes on. Presets the firmware cannot run (open loop, PID, a power
%   limit, a plain integrator, a simulated room step) are skipped and listed.
%   Progress: results/evidence/logs/temp_campaign_<time>.log (+ .csv). The bulb is mains-powered:
%   attend it.
    o = struct('CoolTo', NaN, 'CoolMax', 900, 'Tend', NaN, 'SpAbove', NaN);
    for k = 1:2:numel(varargin), o.(varargin{k}) = varargin{k + 1}; end
    if nargin < 2 || isempty(steps)
        steps = {'T1', 1; 'T2', 1; 'T2', 2; 'T2', 3; 'T3', 1; 'T3', 2; 'T3', 3; 'T4', 1; 'T4', 2; ...
                 'T5', 1; 'T5', 2; 'T5', 3; 'T5', 4; 'T5', 5; 'T5', 6; 'T6', 1};
    end
    logDir = fullfile(templab.repoRoot(), 'results', 'evidence', 'logs');
    if ~isfolder(logDir), mkdir(logDir); end
    logFile = fullfile(logDir, ['temp_campaign_' char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')) '.log']);
    app = temperature_lab(); drawnow;
    assert(app.connect(port), 'templab:campaign:connect', 'could not connect on %s', port);
    pause(3); Tnow = lastT();
    if isnan(o.CoolTo), o.CoolTo = Tnow + 6; end
    say(sprintf('campaign on %s, %d steps; room %.1f C; each run starts below %.1f C', port, size(steps, 1), Tnow, o.CoolTo));
    tags = arrayfun(@(b) strtok(b.Text), app.ui.mb, 'UniformOutput', false);
    rows = cell(0, 7);
    for s = 1:size(steps, 1)
        app.selectMission(find(strcmp(tags, steps{s, 1}), 1)); app.setPreset(steps{s, 2}); drawnow;
        label = app.ui.preset.Items{steps{s, 2}};
        t0 = tic;
        while lastT() >= o.CoolTo && toc(t0) < o.CoolMax, pause(5); end
        Tstart = lastT();
        if ~isnan(o.Tend), app.set('Tend', o.Tend); end
        if ~isnan(o.SpAbove), app.set('setpoint', round(Tstart + o.SpAbove)); end
        drawnow;
        n0 = height(templab.data.register());
        v = app.values();
        say(sprintf('%s  RUN  %s  (from %.1f C, cooled %.0f s; setpoint %g C, %g s)', steps{s, 1}, label, Tstart, toc(t0), v.setpoint, v.Tend));
        t1 = tic; app.runRig(); pause(2);
        if ~app.state().on
            say(sprintf('%s  SKIP %s: %s', steps{s, 1}, label, app.ui.say.Text));
            rows(end + 1, :) = {steps{s, 1}, label, '', 'SKIPPED', app.ui.say.Text, Tstart, 0}; %#ok<AGROW>
            continue
        end
        tend = app.values().Tend;
        while app.state().on && toc(t1) < tend + 120, pause(1); end
        if app.state().on, app.stop(); pause(2); end
        Rg = templab.data.register(); id = ''; res = '';
        if height(Rg) > n0, id = Rg.run_id{end}; res = Rg.result{end}; end
        fault = app.state().fault;
        say(sprintf('%s  DONE %s  %.0f s  %s [%s]%s', steps{s, 1}, label, toc(t1), id, res, ternary(isempty(fault), '', ['  FAULT ' fault])));
        rows(end + 1, :) = {steps{s, 1}, label, id, res, fault, Tstart, toc(t1)}; %#ok<AGROW>
        if ~isempty(fault), app.clearFault(); pause(2); end
    end
    R = cell2table(rows, 'VariableNames', {'mission', 'preset', 'run_id', 'result', 'fault', 'T_start', 'seconds'});
    writetable(R, strrep(logFile, '.log', '.csv'));
    say('campaign finished');

    function T = lastT()
        L = app.link().table(); T = NaN;
        if ~isempty(L) && height(L) > 0
            v = L.temp_raw(isfinite(L.temp_raw)); if ~isempty(v), T = v(end); end
        end
    end
    function say(s)
        line = sprintf('%s  %s', char(datetime('now', 'Format', 'HH:mm:ss')), s);
        fprintf('%s\n', line);
        fid = fopen(logFile, 'a'); fprintf(fid, '%s\n', line); fclose(fid);
    end
end

function v = ternary(c, a, b), if c, v = a; else, v = b; end, end
