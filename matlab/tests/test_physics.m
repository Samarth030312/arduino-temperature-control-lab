function tests = test_physics
%TEST_PHYSICS  Datasheet / dimension physics of the three rigs, the thermal fit, the run register.
    tests = functiontests(localfunctions);
end

function testTemperatureFromTheBulbAndBox(tc)
    [~, D] = templab.temperature.physics();
    tc.verifyEqual(D.K, D.spec.eta * D.spec.bulb_W * D.R_th, 'RelTol', 1e-12);
    tc.verifyEqual(D.tau, D.R_th * D.C, 'RelTol', 1e-12);
    [~, D2] = templab.temperature.physics(struct('mains_V', 115));
    tc.verifyEqual(D2.P_el, D2.spec.bulb_W * 0.5^1.6, 'RelTol', 1e-12, 'filament power at half voltage');
end

function testTemperatureWindupAndAmbient(tc)
    [P, ~] = templab.temperature.physics();
    c = templab.temperature.defaultConfig(); c.P = P; c.mode = 'PI'; c.Kp = 50; c.Ki = 0.5; c.Tend = 1500; c.uMaxPct = 60;   % 60 % of the bulb: enough to reach 45 C, so the windup shows
    c.antiWindup = false; Sw = templab.temperature.simulate(c);
    c.antiWindup = true; Sa = templab.temperature.simulate(c);
    tc.verifyGreaterThan(max(Sw.Traw), max(Sa.Traw) + 2, 'a plain integrator overshoots after saturation');
    c.ambStep = -5; c.tAmb = 600; c.uMaxPct = 100; S = templab.temperature.simulate(c);
    tc.verifyEqual(S.Traw(end), 45, 'AbsTol', 1, 'PI recovers from the room-temperature drop');
end

function testThermalFitOnAStoppedCurve(tc)
    [P, D] = templab.temperature.physics();
    c = templab.temperature.defaultConfig(); c.P = P; c.mode = 'STEP'; c.setpoint = 60; c.Tend = 1800;
    S = templab.temperature.simulate(c);
    m = templab.ident.fitThermal(S.t, S.Traw, S.heat);
    tc.verifyEqual(m.K, D.K, 'RelTol', 0.10);
    tc.verifyEqual(m.tau, D.tau + D.tau_s, 'RelTol', 0.15, 'tau plus the sensor lag');
end

function testRegisterIdsAndLegacy(tc)
    old = getenv('TEMPLAB_DATA_ROOT'); c = onCleanup(@() setenv('TEMPLAB_DATA_ROOT', old));
    tmp = tempname; mkdir(tmp); setenv('TEMPLAB_DATA_ROOT', tmp);
    T = table((0:4)', (100:100:500)', repmat({'S'}, 5, 1), repmat({'PI'}, 5, 1), 30 * ones(5, 1), (1:5)', ...
        'VariableNames', {'seq', 't_ms', 'loop', 'ctrl', 'setpoint', 'meas'});
    r1 = templab.data.saveRun('TEMP', T, struct('ctrl', 'PI', 'Kp', 1), {}, struct('mission', 'T2', 'legacy_id', 'OLD-1'));
    r2 = templab.data.saveRun('TEMP', T, struct('ctrl', 'P'), {}, struct('mission', 'T5', 'result', 'STOPPED: test'));
    tc.verifyMatches(r1.runId, '^TEMP-R0001_\d{8}-\d{6}_T2$');
    tc.verifyMatches(r2.runId, '^TEMP-R0002_\d{8}-\d{6}_T5$');
    R = templab.data.register();
    tc.verifyEqual(height(R), 2); tc.verifyEqual(R.result{2}, 'STOPPED: test');
    tc.verifyEqual(templab.data.resolve('OLD-1'), r1.runId);
end
