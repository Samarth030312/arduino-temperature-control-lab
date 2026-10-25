function tempRigPose(h, powerPct, tempC, spC, tAmb, tMax)
%TEMPRIGPOSE  Glow, tint and SSR LED of a templab.ui.tempRig scene.
%   powerPct  heater power delivered now (0-100 %); tempC the reading; spC the setpoint;
%   tAmb, tMax the ambient and the full-power temperature (for the tint scale).
    if ~isvalid(h.bulb), return; end
    p = min(max(powerPct / 100, 0), 1); if ~isfinite(p), p = 0; end
    warm = [1.00 0.78 0.35]; cold = [0.85 0.86 0.88];
    set([h.bulb h.neck], 'FaceColor', cold + p * (warm - cold));
    set(h.fil, 'Color', [0.4 0.35 0.3] + p * ([1 0.95 0.7] - [0.4 0.35 0.3]));
    set(h.glow, 'FaceAlpha', 0.22 * p, 'Visible', p > 0.02);
    x = 0; if isfinite(tempC) && tMax > tAmb, x = min(max((tempC - tAmb) / (tMax - tAmb), 0), 1); end
    set(h.zone, 'EdgeColor', [0.40 0.60 0.90] + x * ([1.00 0.35 0.15] - [0.40 0.60 0.90]), 'LineWidth', 1 + 2 * x);
    set(h.ssrLed, 'MarkerFaceColor', [0.3 0.05 0.05] + (p > 0) * [0.7 0.1 0.05]);
end
