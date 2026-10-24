function P = params()
%PARAMS  Temperature rig parameters (bulb heater, DHT sensor, SSR), with provenance.
%
%   P = templab.temperature.params()      P.<name> value, P.meta.<name> status/unit/source
%
%   NOTHING here is measured. The thermal constants are engineering estimates
%   for a 60 W bulb heating a small enclosed volume with the sensor near it;
%   TEMP-01 (heater step test) must replace them.

    P = struct(); P.meta = struct();
    add('P_bulb',    60,    'W',   'ASSUMED',   'user', 'bulb rating as reported; label not inspected (OI-T2)');
    add('eta_heat',  0.9,   '-',   'ESTIMATED', '',     'fraction of incandescent bulb power that becomes heat');
    add('R_th',      1.0,   'K/W', 'ESTIMATED', '',     'sensor-zone to ambient; full power -> ~54 K rise');
    add('C_th',      150,   'J/K', 'ESTIMATED', '',     'gives tau = R C = 150 s');
    add('T_amb',     30,    'degC','ASSUMED',   '',     'lab ambient (Ahmedabad)');
    add('delay',     3,     's',   'ESTIMATED', '',     'heat transport bulb -> sensor');
    add('tau_dht22', 8,     's',   'ESTIMATED', '',     'sensor body lag in still air');
    add('tau_dht11', 10,    's',   'ESTIMATED', '',     '');
    add('per_dht22', 2,     's',   'ESTIMATED', 'SRC-009', 'AM2302 minimum sampling period 2 s (datasheet not yet filed)');
    add('per_dht11', 1,     's',   'ESTIMATED', 'SRC-013', 'DHT11 sampling period 1 s (datasheet not yet filed)');
    add('res_dht22', 0.1,   'degC','ESTIMATED', 'SRC-009', 'reported resolution');
    add('res_dht11', 1.0,   'degC','ESTIMATED', 'SRC-013', 'reported resolution');
    add('noise',     0.05,  'degC','ESTIMATED', '',     'sensor noise, 1 sigma');
    add('range_dht11', [0 50], 'degC', 'UNVERIFIED', 'SRC-009', 'typical DHT11 datasheet value; the datasheet is not yet filed');
    add('acc_dht11', 2,     'degC','UNVERIFIED', 'SRC-009', 'typical DHT11 datasheet accuracy +/- 2 C');
    add('range_dht22', [-40 80], 'degC', 'UNVERIFIED', 'SRC-009', 'typical AM2302 datasheet value');
    add('acc_dht22', 0.5,   'degC','UNVERIFIED', 'SRC-009', 'typical AM2302 datasheet accuracy +/- 0.5 C');
    add('Ts',        0.01,  's',   'VERIFIED_FROM_MANUAL', 'SRC-001', 'course: sampling time 0.01 s (p.17)');
    add('pwm_hz',    16e6 / (64 * 510), 'Hz', 'VERIFIED_FROM_MANUAL', 'SRC-004', 'Uno pin 9: 16 MHz / 64 / 510 = 490.196 Hz (not locked to mains)');
    add('mains_hz',  50,    'Hz',  'ASSUMED',   '',     'India 230 V 50 Hz');
    add('T_cutoff',  70,    'degC','ASSUMED',   '',     'firmware over-temperature cut-off (safety choice)');

    function add(name, value, unit, status, source, note)
        P.(name) = value;
        P.meta.(name) = struct('unit', unit, 'status', status, 'source', source, 'note', note);
    end
end
