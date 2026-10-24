# Open items and conflicts

An item closes only with evidence (a measurement, an inspection photo, or a document quote).
Record how it was closed.

| ID | Fact needed | Why it matters | How to resolve | Status |
|---|---|---|---|---|
| OI-T1 | The bulb: type and rating (W, V) | heater power, K | the bulb's label | OPEN |
| OI-T2 | The box: inside dimensions and material | heat loss, τ | measure | OPEN |
| OI-T3 | The SSR: part number, input range, zero-crossing or random | the flicker under P, whether 5 V drives it | the relay's label and datasheet | OPEN |
| OI-T4 | The LCD: parallel or I2C (and the I2C address) | which build to flash | inspection | OPEN |
| OI-T5 | Where the sensor sits relative to the bulb | θ, and whether the box behaves as one mass | photo of the rig | OPEN |
| OI-T6 | First rig session: T1 (K, τ, θ), then T2–T8 | every prediction in this repository | a session with the rig | OPEN |
| C-T1 | The course asks for N = 500 at Ts = 10 ms; the DHT11 updates once a second | a 5 s window holds about 5 distinct readings | stated in the guide; simulated | NOTED |
