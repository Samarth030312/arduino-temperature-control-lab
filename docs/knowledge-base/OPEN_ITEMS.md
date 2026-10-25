# Open items and conflicts

An item closes only with evidence (a measurement, an inspection photo, or a document quote).
Record how it was closed.

| ID | Fact needed | Why it matters | How to resolve | Status |
|---|---|---|---|---|
| OI-T1 | The bulb: type and rating (W, V) | heater power, K | the bulb's label | CLOSED 2026-10-26: Philips clear incandescent, 40 W, 415 lm (label; EAN 8718291678403), B22 holder |
| OI-T2 | The box: inside dimensions and material | heat loss, τ | measure | OPEN |
| OI-T3 | The SSR: part number, input range, zero-crossing or random | the flicker under P, whether 5 V drives it | the relay's label and datasheet | CLOSED 2026-10-26: Fotek SSR-40DA, input 3–32 V DC, load 24–380 V AC (label); 5 V from D9 switches it on every rig run |
| OI-T4 | The LCD: parallel or I2C (and the I2C address) | which build to flash | inspection | CLOSED 2026-10-26: no LCD; the MATLAB app is the display, the LCD code is removed |
| OI-T5 | Where the sensor sits relative to the bulb | θ, and whether the box behaves as one mass | photo of the rig | OPEN |
| OI-T6 | First rig session: T1 (K, τ, θ), then T2–T8 | every prediction in this repository | a session with the rig | PARTLY: 2026-10-26, 13 runs ([session](../../results/reports/temperature/2026-10-26/README.md)); full-length T3–T6 runs on one unchanged rig still to do |
| OI-T7 | Why the rig changed between T1 and T2 on 2026-10-26 (heating 0.18 → 0.065 °C/s at full power) | which plant the 2026-10-26 runs belong to | ask the operator; photo of the sensor and box; repeat T1 | OPEN |
| C-T1 | The course asks for N = 500 at Ts = 10 ms; the firmware reads the DHT11 every 2 s (its datasheet asks for > 2 s) | a 5 s window holds 2 or 3 distinct readings | stated in the guide; simulated; run on the rig 2026-10-26 (TEMP-R0010) | NOTED |
