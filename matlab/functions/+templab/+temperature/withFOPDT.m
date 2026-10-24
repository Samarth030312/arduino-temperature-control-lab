function c = withFOPDT(c, K, tau, theta)
%WITHFOPDT  Set the thermal model from an identified first-order-plus-dead-time fit.
%
%   c = templab.temperature.withFOPDT(c, K, tau, theta)
%
%   K      C of rise above ambient at full power (u = 255)
%   tau    s, time constant;  theta  s, dead time
%   The model C dT/dt = eta P h - (T - Ta)/R has K = eta P R and tau = R C. With R kept,
%   eta P = K / R and C = tau / R. The dead time replaces the transport delay and the
%   sensor-body lag is set to one sample (Ts) (the fit already contains it). Status becomes MEASURED
%   only if the caller says so; here it is marked 'FITTED'.
    P = c.P;
    P.eta_heat = 1; P.P_bulb = K / P.R_th; P.C_th = tau / P.R_th; P.delay = theta;
    P.tau_dht11 = P.Ts; P.tau_dht22 = P.Ts;           % one 10 ms step: no extra lag, stable Euler update
    for n = {'eta_heat', 'P_bulb', 'C_th', 'delay', 'tau_dht11', 'tau_dht22'}
        P.meta.(n{1}).status = 'FITTED (K, tau, theta)';
    end
    c.P = P;
end
