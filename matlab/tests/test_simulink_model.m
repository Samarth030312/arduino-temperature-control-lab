function tests = test_simulink_model
%TEST_SIMULINK_MODEL  Simulink models agree with the MATLAB simulators.
%   Switching systems: compared on metrics (a relay can flip one sample apart),
%   noise off, ideal-average SSR. Skipped without Simulink.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
    tc.assumeTrue(~isempty(ver('simulink')) && license('test', 'Simulink'), 'Simulink not installed');
    tc.TestData.dir = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    build_temperature_simulink(tc.TestData.dir);
end

function testTemperatureModes(tc)
    for mode = {'ONOFF', 'HYST', 'MA', 'P'}
        c = templab.temperature.defaultConfig(); c.mode = mode{1}; c.ssr = 'average'; c.P.noise = 0;
        c.Tend = 600; if strcmp(mode{1}, 'MA'), c.window = 500; end
        M = templab.temperature.simulate(c);
        R = run_temperature_simulink(c, tc.TestData.dir);
        tail = M.t >= 0.7 * c.Tend;
        dMean = abs(mean(M.Traw(tail)) - mean(R.reading(tail)));
        dDuty = abs(mean(M.heat) - mean(R.heat));
        dMax = max(abs(M.T(M.t <= 60) - R.T(M.t <= 60)));      % heating phase, before switching
        fprintf('  temperature %-6s  mean diff %.3f C, duty diff %.3f, early max diff %.3f C\n', mode{1}, dMean, dDuty, dMax);
        tc.verifyLessThan(dMean, 0.3, mode{1});
        tc.verifyLessThan(dDuty, 0.03, mode{1});
        tc.verifyLessThan(dMax, 0.05, mode{1});
    end
end

