function P = params()
%PARAMS  Temperature rig parameters (bulb heater, DHT sensor, SSR), with provenance.
%
%   P = templab.temperature.params()      P.<name> value, P.meta.<name> status/unit/source
%
%   NOTHING here is measured. The thermal constants are engineering estimates
%   for a 60 W bulb heating a small enclosed volume with the sensor near it;
%   TEMP-01 (heater step test) must replace them.

    P = struct(); P.meta = struct();
    add('P_bulb',    40,    'W',   'VERIFIED_FROM_LABEL', 'owner, 2026-10-26', 'Philips clear incandescent, 40 W, 415 lm, EAN 8718291678403 (model not found online), B22 holder');
    add('lumens',    415,   'lm',  'VERIFIED_FROM_LABEL', 'owner, 2026-10-26', '415 lm / 40 W = 10.4 lm/W');
    add('eta_heat',  0.95,  '-',   'ESTIMATED', '',     'share of the power that heats the zone: 10.4 lm/W at ~200-250 lm per radiant W of visible light is ~5 % light, the rest IR and convection; in a closed opaque box even the light ends as heat');
    add('I_bulb',    40 / 230, 'A', 'ESTIMATED', '',    'P / V at 230 V: 0.17 A; hot filament 230^2/40 = 1.3 kOhm, about 10-15 times its cold resistance, so a ~3 A inrush peak for a few ms (far inside the SSR rating)');
    add('R_th',      1.0,   'K/W', 'ESTIMATED', '',     'sensor-zone to ambient; full power -> ~54 K rise');
    add('C_th',      150,   'J/K', 'ESTIMATED', '',     'gives tau = R C = 150 s');
    add('T_amb',     30,    'degC','ASSUMED',   '',     'lab ambient (Ahmedabad)');
    add('delay',     3,     's',   'ESTIMATED', '',     'heat transport bulb -> sensor');
    add('tau_dht22', 8,     's',   'ESTIMATED', '',     'sensor body lag in still air');
    add('tau_dht11', 10,    's',   'VERIFIED_FROM_MANUAL', 'Aosong DHT11 manual', 'temperature response time to 63 % in 1 m/s air at 25 C; slower in still air');
    add('per_dht22', 2,     's',   'ESTIMATED', 'SRC-009', 'AM2302 minimum sampling period 2 s (datasheet not yet filed)');
    add('per_dht11', 2,     's',   'VERIFIED_FROM_MANUAL', 'Aosong DHT11 manual; DHT library 1.4.7', 'more than 2 s between readings (Aosong); the library returns its cached value to faster reads (MIN_INTERVAL 2000 ms)');
    add('res_dht22', 0.1,   'degC','ESTIMATED', 'SRC-009', 'reported resolution');
    add('res_dht11', 1.0,   'degC','VERIFIED_FROM_MANUAL', 'Aosong DHT11 manual', '1 C resolution (integer readings)');
    add('noise',     0.05,  'degC','ESTIMATED', '',     'sensor noise, 1 sigma');
    add('range_dht11', [0 50], 'degC', 'VERIFIED_FROM_MANUAL', 'Aosong DHT11 manual', 'measuring range 0-50 C; above 50 C the readings are outside the specification');
    add('acc_dht11', 2,     'degC','VERIFIED_FROM_MANUAL', 'Aosong DHT11 manual', 'accuracy +/- 2 C');
    add('range_dht22', [-40 80], 'degC', 'UNVERIFIED', 'SRC-009', 'typical AM2302 datasheet value');
    add('acc_dht22', 0.5,   'degC','UNVERIFIED', 'SRC-009', 'typical AM2302 datasheet accuracy +/- 0.5 C');
    add('Ts',        0.01,  's',   'VERIFIED_FROM_MANUAL', 'SRC-001', 'course: sampling time 0.01 s (p.17)');
    add('pwm_hz',    16e6 / (64 * 510), 'Hz', 'VERIFIED_FROM_MANUAL', 'SRC-004', 'Uno pin 9: 16 MHz / 64 / 510 = 490.196 Hz (not locked to mains)');
    add('mains_hz',  50,    'Hz',  'ASSUMED',   '',     'India 230 V 50 Hz');
    add('T_cutoff',  60,    'degC','ASSUMED',   '',     'firmware over-temperature cut-off with the DHT11 (safety choice): above the 55 C set-point, out of real heat for the sensor');
    add('T_cutoff_dht22', 70, 'degC', 'ASSUMED', '',    'the same with a DHT22 (reads to 80 C)');
    add('ssr_zero_cross', 1, '-',  'VERIFIED_FROM_MANUAL', 'Fotek SSR-40DA (distributor copy of the datasheet)', 'switches only at mains zero crossings: on/off decided every 10 ms half-cycle');
    add('ssr_input',  [3 32], 'V', 'VERIFIED_FROM_LABEL', 'owner, 2026-10-26', 'Fotek SSR-40DA input 3-32 V DC, output 24-380 V AC 40 A; input about 7.5 mA at 12 V');
    add('ssr_leak',  3e-3,  'A',   'VERIFIED_FROM_MANUAL', 'Fotek SSR-40DA (distributor copy)', 'off-state leakage at most 3 mA: the load side is never fully dead with the SSR off');

    function add(name, value, unit, status, source, note)
        P.(name) = value;
        P.meta.(name) = struct('unit', unit, 'status', status, 'source', source, 'note', note);
    end
end
