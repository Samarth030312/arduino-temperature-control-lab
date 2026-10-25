# Rig session 2026-10-26

The first runs on the real rig: Philips clear 40 W bulb in a B22 holder, switched by a Fotek
SSR-40DA from pin 9 of an Arduino Uno, a DHT11 module on pin 7 read every 2 s, both in a closed
box; the room at 24.0 °C (the DHT11, 01:53). 13 runs, `TEMP-R0001` to `TEMP-R0013` in `data/`.
No firmware fault in any run.

| Part | Time | Runs | Report |
|---|---|---|---|
| campaign, full-length runs | 01:53–03:12 | R0001 T1, R0002–R0004 T2 | [0150/REPORT.md](0150/REPORT.md) |
| short runs, every mission | 03:14–03:26 | R0005–R0013, T1–T6 | [0314/REPORT.md](0314/REPORT.md) |

Logs: `results/evidence/logs/temp_campaign_20261026-015307.log` and `…-031406.log` (one line per
run), `hw_session_temp_*.log` (every serial line). The first campaign was planned for 16 runs;
it was stopped by the operator during R0004, so its log has no closing line.

## What the rig showed

**The plant (T1, R0001).** Bulb fully on from 24.0 °C to 50 °C in 220 s, then off for 26 min.
Fit of τ dT/dt = K u(t − θ) − (T − Tₐ) to heating and cooling together: **K = 31.9 °C at full
power, τ = 138 s, θ = 5 s**, RMSE 0.31 °C. Heating starts at 0.18 °C/s.

**The sensor.** A new value every 2.0 s; this DHT11 reports 0.1 °C steps (its datasheet: 1 °C
resolution, ±2 °C accuracy, 0–50 °C).

**The rig changed after T1.** From R0002 on, with the bulb fully on, the reading rose at
0.065 °C/s instead of 0.18 °C/s, levelled off near 37 °C (R0002) and 45–46 °C (R0003, R0004)
instead of about 56 °C, and cooled about three times slower. The firmware drives the SSR the
same way in STEP and ON-OFF mode (`digitalWrite`, pin 9 HIGH while u = 255), so the change is
physical: the sensor's position or the box. It was not recorded ([OI-T7](../../../../docs/knowledge-base/OPEN_ITEMS.md)).
R0004 (on-off at 55 °C, stopped at 550 s at 46.1 °C) is a clean full-power heating curve of the
changed rig: **K = 22.4 °C, τ = 143 s, θ = 0 s**, RMSE 0.33 °C (Tₐ = 24.0 °C).

**On-off (T2).** At 35 °C: swing 0.9 °C, switching every 24 s. At 45 °C, where the full-power
limit was close: swing 0.4 °C, every 80 s; the reading crept up to the setpoint instead of
overshooting it.

**Short runs (T1–T6, 75 s each).** Every mission ran on the rig. The runs were back to back
from a warm box (36.7–49.2 °C), each setpoint 3 °C above the reading at its start. They are
shorter than τ: they show each controller's switching and first approach, not settled values.
On-off at 43 °C switched every 10 s with a 0.3 °C swing; the hysteresis band of 4 °C never
switched within the run; P control at Kp 1 left the bulb practically off (u = 3 to 10 of 255) and
the box cooled from 47.9 to 41.3 °C.

## Replayed in MATLAB and Simulink

Every run, with its own recorded settings and starting temperature, on the plant identified
for its part of the session (`matlab/scripts/temperature_replay_runs.m`; SSR as its average
power in both simulators). RMSE of the reading, °C:

| Run | Mode | Plant | rig − MATLAB | rig − Simulink | MATLAB − Simulink |
|---|---|---|---:|---:|---:|
| R0001 | STEP | R0001 | 0.88 | (MATLAB only) | |
| R0002 | ONOFF | R0001 | 2.34 | 2.34 | 0.017 |
| R0003 | ONOFF | R0001 | 2.63 | 2.63 | 0.190 |
| R0002 | ONOFF | R0004 | 1.86 | 1.86 | 0.037 |
| R0003 | ONOFF | R0004 | 1.07 | 1.07 | 0.007 |
| R0004 | ONOFF | R0004 | 0.30 | 0.29 | 0.006 |
| R0005 | STEP | R0004 | 0.60 | (MATLAB only) | |
| R0006 | ONOFF | R0004 | 0.94 | 0.94 | 0.000 |
| R0007 | HYST | R0004 | 1.36 | 1.36 | 0.000 |
| R0008 | HYST | R0004 | 1.26 | 1.26 | 0.000 |
| R0009 | MA | R0004 | 0.71 | 0.71 | 0.000 |
| R0010 | MA | R0004 | 0.67 | 0.67 | 0.000 |
| R0011 | P | R0004 | 0.80 | 0.80 | 0.000 |
| R0012 | P | R0004 | 1.80 | 1.80 | 0.016 |
| R0013 | PI | R0004 | 0.67 | 0.67 | 0.000 |

Tables: `results/tables/temperature_replay_2026-10-26_*.csv`.

- **MATLAB and Simulink agree** on every run Simulink can model, to 0.04 °C or better (0.19 °C
  on R0003, where a relay switches one controller sample apart).
- **The T1 plant does not describe R0002–R0003** (2.3–2.6 °C); the R0004 plant does better
  (1.1–1.9 °C), but R0002 still drifts: the rig was still changing then.
- **The short runs** are 0.6–1.8 °C from the R0004 plant, the rig reading warmer: they started
  in a box heated for over an hour, whose walls store heat that a single time constant does not
  hold.

## Next session

1. Photograph the sensor, the bulb and the box as they are; leave them so for the whole session.
2. T1 once from room temperature (≈ 30 min): the plant for every other run.
3. T2–T6 at full length (≈ 15 min each, about 5 τ), cooling below room + 6 °C between runs;
   setpoints below the measured full-power temperature (Tₐ + K) minus a few °C.
4. Generate the report, then replay every run (`temperature_session_report`,
   `temperature_replay_runs`).
