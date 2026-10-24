function p = presets()
%PRESETS  Named temperature experiments (TEMP handout SRC-015 + course file SRC-001 p.17).
%   Sensor DHT11 (lab) unless the name says otherwise. Desired temperatures 35 / 45 / 55 C.
    p = struct('name', {}, 'experiment', {}, 'set', {});
    add('Sensor only, heater off',                 'TEMP-01', {'setpoint', 0, 'Tend', 120});
    add('Heater step: full ON to 55 C, then cool (K, tau, theta)', 'TEMP-01', {'mode', 'STEP', 'setpoint', 55, 'Tend', 1200});
    add('On-off, 35 C',                            'TEMP-02', {'setpoint', 35});
    add('On-off, 45 C',                            'TEMP-02', {'setpoint', 45});
    add('On-off, 55 C',                            'TEMP-02', {'setpoint', 55});
    add('On-off with hysteresis +/-0.5 C, 45 C',   'TEMP-02', {'mode', 'HYST', 'hyst', 1});
    add('On-off with hysteresis +/-1 C, 45 C',     'TEMP-02', {'mode', 'HYST', 'hyst', 2});
    add('Moving average N = 10, 45 C',             'TEMP-03', {'mode', 'MA', 'window', 10});
    add('Moving average N = 500, 45 C',            'TEMP-04', {'mode', 'MA', 'window', 500});
    add('P control Kp = 1, 45 C',                  'TEMP-06', {'mode', 'P', 'Kp', 1});
    add('P control Kp = 2, 45 C',                  'TEMP-06', {'mode', 'P', 'Kp', 2});
    add('P control Kp = 50, 45 C',                 'TEMP-06', {'mode', 'P', 'Kp', 50});
    add('P control Kp = 100, 45 C',                'TEMP-06', {'mode', 'P', 'Kp', 100});
    add('P control Kp = 500, 45 C',                'TEMP-06', {'mode', 'P', 'Kp', 500});
    add('P Kp = 50, time-proportional SSR, 45 C',  'TEMP-06', {'mode', 'TPROP', 'Kp', 50});
    add('PI Kp = 50, Ki = 0.5, 45 C (anti-windup)', 'TEMP-08', {'mode', 'PI', 'Kp', 50, 'Ki', 0.5});
    add('P control Kp = 50, 55 C',                 'TEMP-07', {'mode', 'P', 'Kp', 50, 'setpoint', 55});
    add('On-off with DHT22 instead, 45 C',         'TEMP-07', {'sensor', 'DHT22'});

    function add(name, exp, set)
        p(end + 1) = struct('name', name, 'experiment', exp, 'set', {set});
    end
end
