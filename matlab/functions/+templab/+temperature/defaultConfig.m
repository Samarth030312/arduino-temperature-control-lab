function c = defaultConfig()
%DEFAULTCONFIG  Runnable temperature-experiment configuration.
%
%   mode    'ONOFF'  heater on below the setpoint, off above (course task 4)
%           'HYST'   on-off with a hysteresis band (flicker reduction)
%           'MA'     on-off on a moving average of the readings (task 5)
%           'P'      u = Kp e, clamped 0..255 (task 6)
%           'TPROP'  P with a slow time-proportioning window (flicker reduction)
%           'STEP'   bulb fully ON until the reading reaches the setpoint, then OFF:
%                    heating + cooling curves for the K, tau, theta fit (handout S3-5)
%           'PI'     u = Kp e + Ki integral(e), 0..255, clamping anti-windup (S3-12)
%   ssr     'pwm490' course wiring: analogWrite(9,u) into a zero-cross SSR
%           'average' heater power = u/255 (idealised; used by the Simulink model)
    c.mode = 'ONOFF';
    c.sensor = 'DHT11';    % lab sensor (owner, 2026-10-21)
    c.setpoint = 45;
    c.hyst = 1.0;          % degC, full band
    c.window = 10;         % moving-average samples at Ts
    c.Kp = 50;             % per degC, output 0..255
    c.Ki = 0;              % per degC per s (PI only)
    c.ssr = 'pwm490';
    c.tprop = 2;           % s
    c.Tend = 900;          % s
    c.seed = 1;
    c.experiment = '';
    c.P = templab.temperature.params();
end
