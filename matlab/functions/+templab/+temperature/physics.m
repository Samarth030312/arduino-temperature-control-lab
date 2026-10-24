function [P, D] = physics(spec)
%PHYSICS  Thermal parameters from the bulb, the enclosure and the sensor you describe.
%
%   [P, D] = templab.temperature.physics()            % defaults (all ASSUMED until measured)
%   [P, D] = templab.temperature.physics(spec)        % any subset of D.spec's fields
%
%   Inputs (spec):
%     bulb_W 60, bulb_V 230 (its rating), mains_V 230 (what the socket gives),
%     eta 0.90 (share of electrical power that becomes heat near the sensor: ~0.9 for an
%       incandescent or halogen bulb, ~0.3 for an LED bulb),
%     box_L, box_W, box_H 0.30 m (enclosure inside), U 1.85 W/m^2K (overall wall loss,
%       incl. convection; ~1-2 thick cardboard / wood, ~4-6 thin plastic or metal),
%     m_struct 0.13 kg, c_struct 900 J/kgK (holder, walls near the sensor that heat with it),
%     T_amb 30 C, theta 3 s (bulb -> sensor transport), tau_s 10 s (DHT11 body lag).
%   Physics (one lumped thermal mass):
%     P_el = bulb_W (mains_V / bulb_V)^1.6         filament resistance rises with temperature
%     G    = U A,  A = 2 (LW + LH + WH)             heat-loss conductance, R_th = 1 / G
%     C    = rho_air c_air V + m_struct c_struct     heat capacity
%     C dT/dt = eta P_el u - (T - T_amb) / R_th      u = heater on-fraction 0..1
%     K = eta P_el R_th (rise at full power), tau = R_th C, theta, plus the sensor lag
%   P is templab.temperature.params() with these values in place, for simulate; D holds the
%   derived numbers.
    def = struct('bulb_W', 60, 'bulb_V', 230, 'mains_V', 230, 'eta', 0.90, 'box_L', 0.30, 'box_W', 0.30, ...
        'box_H', 0.30, 'U', 1.85, 'm_struct', 0.13, 'c_struct', 900, 'T_amb', 30, 'theta', 3, 'tau_s', 10);
    if nargin < 1, spec = struct(); end
    for f = fieldnames(def)', if ~isfield(spec, f{1}) || isempty(spec.(f{1})), spec.(f{1}) = def.(f{1}); end, end
    Pel = spec.bulb_W * (spec.mains_V / spec.bulb_V)^1.6;
    A = 2 * (spec.box_L * spec.box_W + spec.box_L * spec.box_H + spec.box_W * spec.box_H);
    V = spec.box_L * spec.box_W * spec.box_H;
    G = spec.U * A; Rth = 1 / G;
    C = 1.2 * 1005 * V + spec.m_struct * spec.c_struct;
    P = templab.temperature.params();
    P.P_bulb = Pel; P.eta_heat = spec.eta; P.R_th = Rth; P.C_th = C; P.T_amb = spec.T_amb;
    P.delay = spec.theta; P.tau_dht11 = spec.tau_s; P.tau_dht22 = max(P.Ts, 0.8 * spec.tau_s);
    for n = {'P_bulb', 'eta_heat', 'R_th', 'C_th', 'T_amb', 'delay', 'tau_dht11'}
        P.meta.(n{1}).status = 'ASSUMED'; P.meta.(n{1}).note = 'from the values in templab.temperature.physics';
    end
    K = spec.eta * Pel * Rth;
    D = struct('spec', spec, 'P_el', Pel, 'A', A, 'V', V, 'G', G, 'R_th', Rth, 'C', C, 'K', K, ...
        'tau', Rth * C, 'theta', spec.theta, 'tau_s', spec.tau_s, 'T_max', spec.T_amb + K);
    D.tf = sprintf('T(s)/u(s) = %.1f e^{-%.0fs} / (%.0f s + 1) / (%.0f s + 1)   [C per unit on-fraction]', K, spec.theta, D.tau, spec.tau_s);
end
