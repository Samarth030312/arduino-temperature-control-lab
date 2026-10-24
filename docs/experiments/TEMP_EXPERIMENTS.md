# Temperature experiments TEMP-01 … TEMP-07

> **Pre-registered plans** (2026-10-09), kept as written. Some were written for the DHT22 (a new
> reading every 2 s); the lab sensor is a DHT11 (every 1 s). In the app these experiments are the
> missions T1–T8.

Project IDs mapped to the course guideline tasks (SRC-001 p.17). Safety gate for every hardware
run: `docs/hardware/WIRING.md` §3 (mains rules), a second person present, enclosure closed.

| ID | Course task | Hypothesis | Hardware acceptance | Status |
|---|---|---|---|---|
| TEMP-01 | 1–3: read the sensor | DHT11 reads room temperature every 1 s at 1 °C resolution. **Also: heater step test** (mode STEP, preset "Heater step") to fit K, τ, θ (handout S3-5). | Reading within ±1 °C of a reference thermometer; step response fitted, `params.m` updated to MEASURED | SIM-DONE |
| TEMP-02 | 4: on-off at 35/45/55 °C | Regulates; band set by sensor lag and the 2 s update; visible flicker at each crossing | Logged reading, setpoint, heater state; band and switchings/min reported per setpoint | SIM-DONE |
| TEMP-03 | 5: moving average N = 10 | No change vs on-off (0.1 s window < 2 s DHT update) | switchings/min within ±15 % of TEMP-02 at 45 °C | SIM-DONE |
| TEMP-04 | 5: moving average N = 500 | Fewer switchings, wider band, more lag | switchings/min lower and band wider than TEMP-03 | SIM-DONE |
| TEMP-05 | 6: display instantaneous error | Error on LCD line 2 and in `$TTEL` | LCD shows e; telemetry e = SP − reading | SIM-DONE (firmware) |
| TEMP-06 | 6: P with Kp = 1, 2, 50, 100, 500 on pin 9 | Offset shrinks with Kp; intense flicker near e = 0 (PWM into zero-cross SSR); Kp = 500 ≈ on-off | e_ss per Kp compared with (SP−Ta)/(1+Kp·G/255) using TEMP-01's G | SIM-DONE |
| TEMP-07 | 6: compare P with on-off; DHT11 vs DHT22 | P: smaller band, offset, more flicker; on-off: no offset, cycling | comparison table + overlay with simulation | SIM-DONE |

Flicker-reduction answer (task 4): hysteresis (preset "On-off with 1 C hysteresis"), the N = 500
moving average, or time-proportioning (`TPROP`, firmware and app).

Evidence: `results/evidence/simulation_runs/temperature/`, hardware `data/raw/temperature/`.
