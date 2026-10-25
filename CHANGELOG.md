# Changelog

## Unreleased

- First rig session (2026-10-26): 13 runs with the real parts (Philips 40 W bulb, Fotek
  SSR-40DA, DHT11, Uno), session reports, and every run replayed in MATLAB and Simulink.
- Firmware: no LCD; DHT11 read every 2 s; cut-off 60 °C with a DHT11 (70 °C with a DHT22); a
  sensor fault only after 5 failed reads in a row; every firmware stop reported to the app.
- App: commands confirmed by ACK and retried; the run ends when the firmware stops running.
- Simulator and Simulink model start from a given temperature (`c.T0`); the model is saved in
  R2023b's format.
- New scripts: `temperature_rig_campaign` (runs the missions in order, recorded; short runs with
  `'Tend'` and `'SpAbove'`), `temperature_session_report`, `temperature_replay_runs`.

## 1.0.0 (2026-10-25): first public release

The Arduino temperature control lab, released on its own: the Arduino firmware with its safety cut-offs, the
`temperature_lab` app (missions, a 3-D rig, physics from the parts you describe, the SIM / RIG / REF
table, recording, replay, overlay, OPEN IN SIMULINK), a Simulink model generated from code,
the firmware tested on the PC against an emulated rig, and one-line set-up on Windows, macOS
and Linux with CI on all three. Not yet run on a real rig.
