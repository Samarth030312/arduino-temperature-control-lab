# Results

**First rig session: 2026-10-26**, 13 runs, every mission T1–T6 at least once
([session page](../results/reports/temperature/2026-10-26/README.md)). Measured: the plant at full
power K = 31.9 °C, τ = 138 s, θ = 5 s (T1), the DHT11 updating every 2.0 s in 0.1 °C steps,
on-off swings of 0.4–0.9 °C. The rig changed after T1 (cause not recorded, OI-T7), so the later
runs are compared with a plant fitted to a later run (K = 22.4 °C, τ = 143 s). The T3–T6 runs
were 75 s long: their settled errors and swings are still to be measured.

Every run replayed in the MATLAB simulator and in Simulink: the two agree to 0.04 °C or better
(0.19 °C on one on-off run); against the rig, 0.3–1.9 °C RMSE on the plant identified for that
part of the session.

| What | Where |
|---|---|
| the predictions, mission by mission | the app: every mission's SIM and REF columns; [first principles](FIRST_PRINCIPLES.md) |
| the firmware against the emulated rig | `firmware/tests/firmware_host_test.cpp` (run by `scripts/validation/host_tests.sh` and CI) |
| the app, the firmware and the emulated rig end to end | `matlab/tests/e2e/e2e_mission_control.m` (CI, Linux) |
| Simulink against the MATLAB model | `matlab/tests/test_simulink_model.m` |
| rig runs replayed in both simulators | `matlab/scripts/temperature_replay_runs.m`, `results/tables/temperature_replay_*.csv` |
| a session's report from `data/` | `matlab/scripts/temperature_session_report.m` |

Each session's report goes to `results/reports/temperature/<date>/`; this page lists what the
rig showed against each prediction, as the
[DC servo lab](https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/blob/main/docs/RESULTS.md) does.
