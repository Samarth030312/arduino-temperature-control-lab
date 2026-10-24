function h = tempRig(ax)
%TEMPRIG  3-D temperature rig: bulb in its holder, DHT11, SSR, Uno and 16x2 LCD.
%
%   h = templab.ui.tempRig(ax);   templab.ui.tempRigPose(h, powerPct, tempC, setpointC, tAmb, tMax)
%
%   Sizes: E27 holder D40 x 45 (typical), A60 bulb D60 x 105 (standard A60 shape),
%   DHT11 module 15.5 x 12 x 5.5 (common breakout), SSR-40DA 62 x 45 x 23 (typical case;
%   the lab relay's part number is not yet recorded, OI-T2), Uno 68.6 x 53.4, 1602 LCD
%   module 80 x 36 (HD44780 board). The faint box is the heated zone of the model
%   (dimensions in the physics panel; ASSUMED). The bulb glows with the delivered power,
%   the zone tints with temperature, the SSR LED shows its input, the LCD shows the reading.
    K = templab.ui.palette();
    hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off'); ax.Color = 'none'; ax.Clipping = 'off';
    try, ax.Toolbar.Visible = 'off'; catch, end
    try, disableDefaultInteractivity(ax); catch, end
    view(ax, 38, 18);
    xlim(ax, [-0.17 0.17]); ylim(ax, [-0.21 0.13]); zlim(ax, [0 0.24]);
    zB = 0.006;
    box3([0 -0.04 zB / 2], [0.34 0.34 zB], [0.13 0.14 0.17], ax);                 % bench plate
    % heated zone (faint box) and its tint
    Z = [0.24 0.20 0.20]; c0 = [0 0.02 zB + Z(3) / 2];
    h.zone = box3(c0, Z, [0.4 0.6 0.9], ax); set(h.zone, 'FaceColor', 'none', 'EdgeColor', [0.40 0.60 0.90], 'LineWidth', 1.2);   % outline only: fast
    % E27 holder and A60 bulb (bulb axis vertical)
    cyl(ax, [0 0.02 zB], 0.020, 0.045, [0.92 0.92 0.90]);
    cyl(ax, [0 0.02 zB + 0.045], 0.0135, 0.018, [0.75 0.75 0.78]);              % screw base
    [X, Y, Zs] = sphere(28); r = 0.030;
    h.bulb = surf(ax, r * X, 0.02 + r * Y, zB + 0.063 + 0.042 + r * Zs, 'EdgeColor', 'none', ...
        'FaceColor', [0.85 0.86 0.88], 'FaceLighting', 'gouraud', 'SpecularStrength', 0.9);
    [Xc, Yc, Zc] = cylinder([0.0135 0.022 0.029], 28);
    h.neck = surf(ax, Xc, 0.02 + Yc, zB + 0.063 + Zc * 0.042, 'EdgeColor', 'none', 'FaceColor', [0.85 0.86 0.88]);
    h.fil = plot3(ax, [-0.006 0.006], [0.02 0.02], zB + 0.105 * [1 1], '-', 'Color', [0.4 0.35 0.3], 'LineWidth', 2.5);
    [Xg, Yg, Zg] = sphere(12); rg = 0.06;                       % the one transparent object
    h.glow = surf(ax, rg * Xg, 0.02 + rg * Yg, zB + 0.105 + rg * Zg, 'EdgeColor', 'none', 'FaceColor', [1 0.65 0.2], ...
        'FaceAlpha', 0, 'FaceLighting', 'none', 'Visible', 'off');
    % DHT11 on a wire stand, 80 mm from the bulb axis
    pS = [0.08 0.02 zB + 0.10];
    plot3(ax, [pS(1) pS(1)], [pS(2) pS(2)], [zB pS(3) - 0.006], '-', 'Color', K.dim, 'LineWidth', 1.5);
    box3(pS, [0.0155 0.0055 0.012], [0.15 0.45 0.85], ax);
    for k = -2:2, plot3(ax, pS(1) + [-0.006 0.006], pS(2) - 0.0029 * [1 1], pS(3) + 0.002 * k * [1 1], '-', 'Color', [0.85 0.9 1], 'LineWidth', 1); end
    % SSR-40DA, Uno, LCD in front of the zone
    pR = [-0.10 -0.14 zB + 0.0115];
    box3(pR, [0.062 0.045 0.023], [0.95 0.95 0.93], ax);
    box3(pR + [0 0 0.0118], [0.050 0.030 0.0006], [0.12 0.12 0.13], ax);
    h.ssrLed = plot3(ax, pR(1) + 0.018, pR(2) - 0.012, pR(3) + 0.0125, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.3 0.05 0.05], 'MarkerEdgeColor', 'none');
    pU = [0.01 -0.15 zB + 0.008];
    box3(pU, [0.0686 0.0534 0.0016], [0.00 0.44 0.55], ax);
    box3(pU + [-0.030 0.012 0.0063], [0.016 0.012 0.011], [0.70 0.72 0.75], ax);
    box3(pU + [0.010 -0.006 0.002], [0.035 0.0075 0.003], [0.06 0.06 0.07], ax);
    pL = [0.115 -0.13 zB + 0.018];
    box3(pL, [0.080 0.006 0.036], [0.05 0.40 0.20], ax);                        % upright LCD board
    box3(pL + [0 -0.0035 0.001], [0.064 0.0012 0.016], [0.12 0.30 0.75], ax);   % screen
    h.lcd1 = text(ax, pL(1) - 0.030, pL(2) - 0.006, pL(3) + 0.0055, 'T --.- C', 'Color', [0.85 0.95 1], 'FontName', K.mono, 'FontSize', 7, 'FontWeight', 'bold');
    h.lcd2 = text(ax, pL(1) - 0.030, pL(2) - 0.006, pL(3) - 0.0035, 'S --  H ---%', 'Color', [0.85 0.95 1], 'FontName', K.mono, 'FontSize', 7, 'FontWeight', 'bold');
    % cables: mains to bulb through the SSR (load side), DHT to the Uno, SSR input from D9
    cable(ax, [pR + [-0.02 0.02 0.01]; -0.08 -0.02 0.02; -0.005 0.02 zB + 0.02], [0.08 0.08 0.08], 2.4);
    cable(ax, [pR + [0.02 0.02 0.01]; -0.04 -0.03 0.02; 0.005 0.02 zB + 0.02], [0.55 0.35 0.15], 2.4);
    cable(ax, [-0.17 -0.14 zB + 0.01; -0.15 -0.14 zB + 0.01; pR + [-0.031 0 0]], [0.08 0.08 0.08], 3);
    cable(ax, [pS - [0 0 0.006]; 0.07 -0.06 0.03; pU + [0.02 0.0245 0.004]], [0.95 0.85 0.20], 1.2);
    cable(ax, [pU + [-0.01 0.0245 0.004]; -0.05 -0.12 0.02; pR + [0.031 0 0]], [0.25 0.45 0.95], 1.2);
    cable(ax, [pU + [0.03 -0.0245 0.004]; 0.08 -0.16 0.02; pL + [-0.04 0 0]], [0.85 0.15 0.15], 1.0);
    lab = @(p, s) text(ax, p(1), p(2), p(3), s, 'Color', K.dim, 'FontSize', 9, 'HorizontalAlignment', 'center');
    h.labels = [lab([0 0.02 zB + 0.17], 'bulb · E27'), lab(pS + [0 0 0.02], 'DHT11'), lab(pR + [0 0 0.03], 'SSR'), ...
                lab(pU + [0 0 0.02], 'Arduino Uno'), lab(pL + [0 0 0.028], 'LCD 16x2')];
    light(ax, 'Position', [0.6 -0.8 1.0]); light(ax, 'Position', [-0.5 0.5 0.6], 'Color', [0.35 0.35 0.40]);
    h.K = K;
    templab.ui.tempRigPose(h, 0, 30, 45, 30, 84);
end

function p = box3(c, d, col, parent)
    [X, Y, Z] = ndgrid([-1 1] * d(1) / 2, [-1 1] * d(2) / 2, [-1 1] * d(3) / 2);
    V = [X(:) Y(:) Z(:)] + c;
    F = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
    shade = [0.70 0.70 0.86 0.86 0.78 1.00]';
    p = patch('Vertices', V, 'Faces', F, 'FaceVertexCData', min(1, shade * col), 'FaceColor', 'flat', ...
              'EdgeColor', col * 0.5, 'LineWidth', 0.5, 'FaceLighting', 'none', 'Parent', parent);
end

function cyl(ax, b, r, len, col)
    [X, Y, Z] = cylinder(r, 36);
    surf(ax, X + b(1), Y + b(2), Z * len + b(3), 'FaceColor', col, 'EdgeColor', 'none', 'FaceLighting', 'gouraud');
    th = linspace(0, 2 * pi, 37);
    patch(ax, b(1) + r * cos(th), b(2) + r * sin(th), b(3) + len + 0 * th, col * 0.95, 'EdgeColor', 'none');
end

function cable(ax, P, col, w)
    t = linspace(0, 1, 24)';
    B = (1 - t).^2 .* P(1, :) + 2 * (1 - t) .* t .* P(2, :) + t.^2 .* P(3, :);
    plot3(ax, B(:, 1), B(:, 2), B(:, 3), '-', 'Color', col, 'LineWidth', w);
end
