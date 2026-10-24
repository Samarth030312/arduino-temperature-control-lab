# Temperature mission control: `temperature_lab`

```matlab
setup open               % from the repository folder
```

![temperature_lab](../../results/figures/app_mission_control.png)

## The screen

**Left:** the mission, its presets, the controller, a
disturbance, and the **physics panel** (bulb · enclosure · sensor). **Centre:** the rig in 3-D:
the bulb glows with the power it receives, the heated zone's outline warms from blue to red,
the SSR's LED shows its input, and the LCD shows the reading the Arduino displays. **Right:**
the temperature the DHT11 reports (grey: simulation, cyan: rig, violet: replay; dotted: the true
zone temperature, which the sensor sees late and in 1 °C steps) and the heater power.
**Bottom:** rig controls, the SIM / RIG / REF table, recorded runs.

## The physics panel

Type what is on your bench and the model follows:

| You give | The model uses |
|---|---|
| bulb rating, its rated voltage, the supply voltage, heat fraction η | electrical power P = W (V/V_rated)^1.6 (a filament's resistance rises with temperature); heat into the zone η P |
| zone length, width, height, wall loss U | loss conductance G = U·A, R_th = 1/G |
| structure mass and its specific heat | heat capacity C = air + structure |
| room temperature, bulb-to-sensor delay θ, sensor lag | the dead time and the DHT11's own lag |

Derived and shown live: K (the rise at full power), τ = R_th·C, θ, the full-power temperature and
the transfer function T(s)/u(s). Values marked ASSUMED in the code are placeholders until the
bench is measured; mission T1 measures K, τ and θ.

## Missions

| | Question |
|---|---|
| T1 · Heating curve | How fast and how far does the zone heat with the bulb fully on, and does it cool at the same rate? |
| T2 · On-off | What does the temperature do at 35, 45 and 55 °C, and how often does the bulb switch? |
| T3 · Hysteresis | What happens to the band and to the switching as the hysteresis grows? |
| T4 · Moving average | How do N = 10 and N = 500 differ, given that the DHT11 updates once a second? |
| T5 · P control | What do Kp = 1, 2, 50, 100, 500 do to the error and to the bulb? |
| T6 · PI and PID | What do the integral and derivative terms add? |
| T7 · Disturbance | The room cools by 5 °C at 600 s: who recovers? |
| T8 · Saturation | With the heater limited to 40 %, what does the integrator do? |
| LAB · Free | Anything; on the rig the setpoint changes live. |

The table scores SIM, RIG and REF (theory from the physics: K, τ, θ, P's offset, on-off ripple)
with the same definitions. **OPEN IN SIMULINK** builds `temperature_plant.slx` with the
current settings. On the rig, the firmware runs ON-OFF, HYST, MA, P, TPROP, STEP and PI; PID
and open loop are simulation only.

## On the rig

Wiring and mains safety first: [TEMPERATURE_WIRING.md](../hardware/WIRING.md). Set the
LCD type (parallel or I2C) under CONTROLLER before FLASH FIRMWARE. The firmware switches the
bulb off if MATLAB is silent for 3 s and latches it off at its 70 °C cut-off.
