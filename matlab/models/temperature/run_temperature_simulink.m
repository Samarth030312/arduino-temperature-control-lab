function R = run_temperature_simulink(c, modelDir)
%RUN_TEMPERATURE_SIMULINK  Run temperature_plant.slx with an templab.temperature config.
%   R.t, R.T (zone), R.reading (DHT), R.heat (on-fraction), sampled every 0.1 s.
    here = fileparts(mfilename('fullpath')); if nargin >= 2, here = modelDir; end
    mdl = 'temperature_plant';
    if ~isfile(fullfile(here, [mdl '.slx'])), build_temperature_simulink(here); end
    load_system(fullfile(here, [mdl '.slx'])); cl = onCleanup(@() close_system(mdl, 0));
    w = temperature_simulink_params(c);
    aw = 'clamping'; if isfield(c, 'antiWindup') && ~c.antiWindup, aw = 'none'; end
    set_param([mdl '/PI or PID'], 'AntiWindupMode', aw);
    in = Simulink.SimulationInput(mdl); f = fieldnames(w);
    for k = 1:numel(f), in = in.setVariable(f{k}, w.(f{k}), 'Workspace', mdl); end
    tg = (0:0.1:c.Tend);
    in = in.setModelParameter('SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset', ...
        'ReturnWorkspaceOutputs', 'on', 'OutputOption', 'SpecifiedOutputTimes', 'OutputTimes', mat2str(tg));
    out = sim(in); y = out.yout; v = @(k) y.getElement(k).Values;
    R.t = v(1).Time; R.T = v(1).Data; R.reading = interp1(v(2).Time, v(2).Data, R.t, 'previous', 'extrap');
    R.heat = interp1(v(3).Time, v(3).Data, R.t, 'previous', 'extrap');
end
