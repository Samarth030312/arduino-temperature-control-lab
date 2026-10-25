function mdl = build_temperature_simulink(outDir)
%BUILD_TEMPERATURE_SIMULINK  Generate temperature_plant.slx: the bulb-heated box and its controllers.
%
%   Bulb heater + lumped thermal mass, transport delay, DHT sensor lag, DHT
%   update (zero-order hold) and resolution (quantiser), and the controllers
%   selected by modeSel: 1 on-off, 2 on-off with hysteresis (Relay
%   block), 3 moving average (Discrete FIR, N taps) + on-off, 4 P clamped to
%   0..uTop, 5 PI / PID (Discrete PID, output 0..uTop, clamping anti-windup or none,
%   set per run), 6 open loop (fixed power olPct). An ambient step (ambStep at tAmb)
%   changes the temperature the zone loses heat to. The SSR is modelled by its average power u/255 (the MATLAB model can
%   also do the 490 Hz PWM / zero-cross interaction; Simulink does not).
%   Parameters: model workspace, set by run_temperature_simulink(cfg).

    if nargin < 1, outDir = fileparts(mfilename('fullpath')); end
    mdl = 'temperature_plant';
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); cl = onCleanup(@() close_system(mdl, 0));
    set_param(mdl, 'Solver', 'ode45', 'RelTol', '1e-6', 'MaxStep', '0.01', 'StopTime', 'Tend', ...
        'SaveOutput', 'on', 'SaveFormat', 'Dataset');
    % parameters first: a block's expression (R, J, ...) must never resolve to a variable of the same name in the base workspace
    setVars(mdl, temperature_simulink_params(templab.temperature.defaultConfig()));
    B = @(lib, n, pos, varargin) add_block(lib, [mdl '/' n], 'Position', pos, varargin{:});
    % ------------------------------------------------ plant (deviation from ambient)
    B('simulink/Math Operations/Gain', 'Heater power', [560 40 620 70], 'Gain', 'eta*Pbulb');
    B('simulink/Math Operations/Sum', 'Heat balance', [660 40 680 80], 'Inputs', '+-');
    B('simulink/Math Operations/Gain', '1 over C', [710 45 750 75], 'Gain', '1/Cth');
    B('simulink/Continuous/Integrator', 'dT above ambient', [780 45 810 75], 'InitialCondition', 'dT0');
    B('simulink/Math Operations/Gain', 'loss 1 over R', [700 110 750 140], 'Gain', '1/Rth', 'Orientation', 'left');
    B('simulink/Math Operations/Sum', 'minus ambient change', [770 110 790 140], 'Inputs', '+-', 'Orientation', 'left');
    B('simulink/Sources/Step', 'Ambient step', [820 180 850 210], 'Time', 'tAmb', 'Before', '0', 'After', 'ambStep');
    B('simulink/Continuous/Transport Delay', 'Bulb to sensor', [850 45 900 75], 'DelayTime', 'delay', 'BufferSize', '4096', ...
      'InitialOutput', 'dT0');
    % first-order lag 1/(tauS s + 1) as a state-space block, so that it can start at dT0
    B('simulink/Continuous/State-Space', 'DHT body lag', [930 45 1000 75], 'A', '-1/tauS', 'B', '1/tauS', ...
      'C', '1', 'D', '0', 'InitialCondition', 'dT0');
    B('simulink/Math Operations/Bias', 'plus ambient', [1030 45 1070 75], 'Bias', 'Ta');
    B('simulink/Discrete/Zero-Order Hold', 'DHT update', [1100 45 1130 75], 'SampleTime', 'perDHT');
    B('simulink/Discontinuities/Quantizer', 'DHT resolution', [1160 45 1200 75], 'QuantizationInterval', 'resDHT');
    B('simulink/Math Operations/Bias', 'zone T', [850 120 890 150], 'Bias', 'Ta');
    % ------------------------------------------------ controller (Ts = 10 ms)
    B('simulink/Discrete/Zero-Order Hold', 'Sample 10 ms', [1240 45 1270 75], 'SampleTime', 'Ts');
    B('simulink/Sources/Constant', 'Setpoint', [40 200 80 220], 'Value', 'SP');
    B('simulink/Math Operations/Sum', 'Error', [140 160 160 200], 'Inputs', '+-');
    B('simulink/Logic and Bit Operations/Relational Operator', 'reading below SP', [140 240 180 280], 'Operator', '<');
    B('simulink/Discontinuities/Relay', 'Hysteresis relay', [220 160 260 190], 'OnSwitchValue', 'hyst/2', ...
        'OffSwitchValue', '-hyst/2', 'OnOutputValue', '1', 'OffOutputValue', '0');
    B('simulink/Discrete/Discrete FIR Filter', 'Moving average', [140 320 200 350], 'Coefficients', 'ones(1,N)/N', 'SampleTime', 'Ts');
    B('simulink/Logic and Bit Operations/Relational Operator', 'average below SP', [240 320 280 360], 'Operator', '<');
    B('simulink/Math Operations/Gain', 'Kp', [220 400 260 430], 'Gain', 'Kp');
    B('simulink/Discontinuities/Saturation', '0..255', [290 400 320 430], 'UpperLimit', 'uTop', 'LowerLimit', '0');
    B('simulink/Discrete/Discrete PID Controller', 'PI or PID', [200 480 280 520], 'Controller', 'PID', 'Form', 'Parallel', ...
      'P', 'Kp', 'I', 'Ki', 'D', 'Kd', 'N', '1', 'UseFilter', 'on', 'SampleTime', 'Ts', 'IntegratorMethod', 'Forward Euler', ...
      'FilterMethod', 'Backward Euler', 'LimitOutput', 'on', 'UpperSaturationLimit', 'uTop', 'LowerSaturationLimit', '0', ...
      'AntiWindupMode', 'clamping');
    B('simulink/Math Operations/Gain', 'PID over 255', [310 480 350 510], 'Gain', '1/255');
    B('simulink/Sources/Constant', 'Open-loop power', [310 560 350 580], 'Value', 'olPct/100');
    B('simulink/Math Operations/Rounding Function', 'round', [340 400 370 430], 'Operator', 'round');
    B('simulink/Math Operations/Gain', 'u over 255', [390 400 430 430], 'Gain', '1/255');
    for k = 1:3, B('simulink/Signal Attributes/Data Type Conversion', sprintf('to double %d', k), [300 160 + 90 * (k - 1) 330 190 + 90 * (k - 1)], 'OutDataTypeStr', 'double'); end
    B('simulink/Sources/Constant', 'modeSel', [400 120 440 140], 'Value', 'modeSel');
    B('simulink/Signal Routing/Multiport Switch', 'Controller select', [480 120 510 600], 'Inputs', '6');
    B('simulink/Sinks/Out1', 'zone_T', [940 125 970 140]);
    B('simulink/Sinks/Out1', 'reading', [1300 120 1330 135], 'Port', '2');
    B('simulink/Sinks/Out1', 'heater_fraction', [560 120 590 135], 'Port', '3');
    L = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
    L('Heater power/1', 'Heat balance/1'); L('Heat balance/1', '1 over C/1'); L('1 over C/1', 'dT above ambient/1');
    L('dT above ambient/1', 'minus ambient change/1'); L('Ambient step/1', 'minus ambient change/2');
    L('minus ambient change/1', 'loss 1 over R/1'); L('loss 1 over R/1', 'Heat balance/2');
    L('dT above ambient/1', 'Bulb to sensor/1'); L('Bulb to sensor/1', 'DHT body lag/1'); L('DHT body lag/1', 'plus ambient/1');
    L('plus ambient/1', 'DHT update/1'); L('DHT update/1', 'DHT resolution/1'); L('DHT resolution/1', 'Sample 10 ms/1');
    L('dT above ambient/1', 'zone T/1'); L('zone T/1', 'zone_T/1');
    L('Sample 10 ms/1', 'reading/1');
    L('Setpoint/1', 'Error/1'); L('Sample 10 ms/1', 'Error/2');
    L('Sample 10 ms/1', 'reading below SP/1'); L('Setpoint/1', 'reading below SP/2');
    L('Error/1', 'Hysteresis relay/1');
    L('Sample 10 ms/1', 'Moving average/1'); L('Moving average/1', 'average below SP/1'); L('Setpoint/1', 'average below SP/2');
    L('Error/1', 'Kp/1'); L('Kp/1', '0..255/1'); L('0..255/1', 'round/1'); L('round/1', 'u over 255/1');
    L('reading below SP/1', 'to double 1/1'); L('Hysteresis relay/1', 'to double 2/1'); L('average below SP/1', 'to double 3/1');
    L('modeSel/1', 'Controller select/1');
    L('to double 1/1', 'Controller select/2'); L('to double 2/1', 'Controller select/3');
    L('to double 3/1', 'Controller select/4'); L('u over 255/1', 'Controller select/5');
    L('Error/1', 'PI or PID/1'); L('PI or PID/1', 'PID over 255/1'); L('PID over 255/1', 'Controller select/6');
    L('Open-loop power/1', 'Controller select/7');
    L('Controller select/1', 'Heater power/1'); L('Controller select/1', 'heater_fraction/1');
    n = Simulink.Annotation([mdl '/note']);
    n.Text = ['Temperature control. modeSel: 1 on-off, 2 hysteresis relay, 3 moving average, 4 P, ' ...
              '5 PI / PID (limit uTop, anti-windup per run), 6 open loop. Ambient step: ambStep at tAmb. ' ...
              'Parameters come from temperature_lab (OPEN IN SIMULINK) or run_temperature_simulink(cfg).'];
    n.Position = [40 470 900 500];
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    f = fullfile(outDir, [mdl '.slx']);
    save_system(mdl, f);
    if ~isMATLABReleaseOlderThan('R2024a')          % R2023b is the oldest supported release: save in its format
        tmp = tempname; mkdir(tmp); clt = onCleanup(@() rmdir(tmp, 's'));
        Simulink.exportToVersion(mdl, fullfile(tmp, [mdl '.slx']), 'R2023b');
        close_system(mdl, 0);
        movefile(fullfile(tmp, [mdl '.slx']), f, 'f');
    end
end

function setVars(mdl, w)
    mws = get_param(mdl, 'ModelWorkspace'); f = fieldnames(w);
    for i = 1:numel(f), assignin(mws, f{i}, w.(f{i})); end
end
