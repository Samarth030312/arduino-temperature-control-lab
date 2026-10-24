# First principles: bulb, box, sensor, controller

Code: `templab.temperature.physics` (parameters from what is on the bench),
`templab.temperature.simulate` (the loop), `templab.ident.fitThermal` (K, τ, θ from a run).
Every default below is ASSUMED until measured; type your own in the app's physics panel.

## 1. The heater

An incandescent bulb rated W at V_rated, on a supply V: its filament's resistance rises with
temperature, so the power goes roughly with V^1.6, not V²:

```
P_el = W (V / V_rated)^1.6          60 W at 230 V: 60 W; on 115 V: about 20 W
```

A fraction η of it heats the air near the sensor (about 0.9 for an incandescent or halogen bulb,
about 0.3 for an LED bulb, which turns more of its power into light). The SSR switches it; the
controller's output u (0–255 on pin 9) is the fraction of full power.

## 2. The box

One lumped thermal mass: the air in the box and the structure that warms with it (lamp holder,
walls near the sensor).

```
C dT/dt = η P_el u − (T − T_room) / R_th
R_th = 1 / (U A),  A = 2 (LW + LH + WH)            U: overall wall loss, W/m²K
C    = ρ_air c_air L W H + m c                      air plus structure
```

| Default | Value | Derived | Value |
|---|---|---|---|
| box 0.30 × 0.30 × 0.30 m, U 1.85 W/m²K | | R_th | 1.0 K/W |
| structure 0.13 kg × 900 J/kgK | | C | 150 J/K |
| bulb 60 W, η 0.9, room 30 °C | | K = η P R_th (rise at full power) | 54 °C |
| | | τ = R_th C | 150 s |
| bulb → sensor 3 s, DHT11 lag 10 s | | θ (effective dead time) | about 13 s |

So T(s)/u(s) ≈ K e^(−θs) / (τs + 1): a first-order plant with dead time, and **full power
heats the box to about 84 °C** if nothing stops it (the firmware cuts off at 70 °C).

## 3. The sensor

The DHT11 reports whole degrees, a new value once a second (the DHT22: 0.1 °C every 2 s), and
its body lags the air. Consequences the missions show:

- a moving average over N samples taken every 10 ms averages the **same** reading N times unless
  N × 10 ms is well over a second: N = 10 changes nothing; N = 500 (5 s) smooths and delays;
- a derivative of a 1 °C staircase is spikes: the D term must be computed on new readings only,
  and filtered (the firmware and the model both do).

## 4. Control laws, and what to expect

| Law | Prediction from the model |
|---|---|
| on-off | a limit cycle around the setpoint; its size grows with θ (the heat already on its way when the reading crosses); about 2 °C peak to peak at 35 °C |
| on-off with hysteresis ±h | a band about 2h wider, fewer switches |
| P, u = Kp e | steady error e_ss = (SP − T_room) / (1 + Kp K / 255): large for Kp 1–2, small for Kp 50–100; at Kp 500, P is on-off again |
| P through a zero-cross SSR | at large Kp, u jumps between 0 and 255 every few samples: a flickering bulb; time-proportioning removes the flicker |
| PI, clamping anti-windup | no steady error; integrates only once the heater leaves its limit |
| PI with a plain integrator, heater limited | the integral grows while the heater is at its limit, then overshoots |

## 5. Identifying your rig

Mission T1 runs the bulb fully on, then off. `templab.ident.fitThermal` regresses dT/dt on the
delayed input and on (T − T_room) over a grid of dead times and returns K, τ and θ; the app
shows them in its table for the simulation and for the rig run side by side. Adjust the physics
panel (wall loss U, structure mass, sensor lag) until the SIM column matches the RIG column. Heating and cooling should give the same τ; if they do not,
the box is not one lumped mass (try moving the sensor).
