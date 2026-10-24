# Temperature control — wiring and electrical guidelines

Hardware: Arduino Uno, **DHT11** (lab sensor, as the course specifies; DHT22 supported with -DDHT_KIND=DHT22), SSR-40DA solid-state
relay, 60 W incandescent bulb in a lamp holder, 16x2 LCD. Firmware:
`firmware/temperature_controller/`. Status: pin plan DECIDED; **not yet wired**.

> **This experiment switches 230 V AC mains.** Mains wiring must be done or checked by someone
> qualified, inside a closed enclosure, before anyone powers it. If the lab provides a ready-made
> bulb/SSR box, use it and connect only the low-voltage side described here.

## 1. Pin plan (low-voltage side)

| Arduino Uno | Connects to | Notes |
|---|---|---|
| **D7** | DHT11 DATA | 10 kΩ pull-up DATA→5 V (already on most 3-pin modules) |
| 5 V / GND | DHT11 VCC / GND | |
| **D9** | SSR input **+** (terminal 3) | course: "relay positive terminal to PWM pin 9" |
| **GND** | SSR input **−** (terminal 4) | |
| **D8** | START/STOP push-button → GND | standalone use without MATLAB |
| D12, D11, D5, D4, D3, D2 | LCD RS, E, D4, D5, D6, D7 | parallel LCD (Arduino LCD tutorial wiring) |
| 5 V / GND / 10 kΩ pot | LCD VDD, VSS, V0 (contrast), RW→GND, A/K backlight via 220 Ω | |
| A4 / A5 | LCD SDA / SCL | **only** if the LCD has an I2C backpack; build with `-DLCD_I2C` |

The SSR-40DA input is 3–32 V DC (typical for this part number; **confirm on the actual relay's
label**, OI-T3). D9 at 5 V drives it directly; its input current (~10 mA) is within an Uno pin's rating.

## 2. Diagram

```
   LOW VOLTAGE (Arduino side)                       |  MAINS 230 V AC (inside enclosure)
                                                    |
  +-------------+        +------------+             |    L ----[fuse 1 A]----+
  | Arduino Uno |  D9 -->| 3 (+)      |             |                        |
  |             | GND -->| 4 (-)  SSR-40DA  1 ------|------------------------+
  |          D7 |<-- DHT11 DATA (10k to 5V)    2 ---|--- bulb holder --- N
  |       5V/GND|--- DHT11, LCD                     |    (60 W bulb)
  |  D2-D5,D11,12|--- LCD 16x2                      |    PE (earth) to the metal parts
  |          D8 |---[START/STOP]---GND              |
  +-------------+                                   |
        | USB                                       |   enclosure lid closed before
     laptop                                         |   plugging in
```

SSR output terminals 1/2 switch the **live (L)** conductor in series with the bulb. Neutral goes
straight to the bulb holder. Earth goes to any exposed metal.

## 3. Mains rules

- A **1 A fuse** (or a 2 A MCB) in the live line; 60 W at 230 V is 0.26 A.
- SSR on a heat sink or metal plate if it runs long at high duty (0.26 A is light; the SSR-40DA
  is rated far above this, but verify).
- Mains and low-voltage wiring physically separated; the only crossing is through the SSR.
- Lid closed, plug in last, unplug before touching anything. The bulb gets hot: keep the sensor
  ~3–5 cm away and nothing flammable nearby.
- The firmware cuts the heater at **70 °C** reading and after **5 s without a valid sensor
  reading**, and when MATLAB goes silent for 3 s. These are backups, not a substitute for
  attending the experiment.

## 4. SSR type matters (zero-cross vs random)

Most SSR-40DA units are **zero-crossing**: they only switch at mains zero crossings (every 10 ms
at 50 Hz). With the course's `analogWrite(9, u)` (490 Hz PWM) the bulb therefore gets a
pseudo-random pattern of half-cycles — the "intense flickering" the guideline asks about. The
firmware's `TPROP` mode (time-proportioning, 2 s window) gives the same average power with far
less flicker. Both are simulated in `temperature_lab`.

## 5. Bring-up order

1. Low-voltage side only (no mains plugged in). Upload: `scripts/setup/upload temperature /dev/ttyACM0`.
2. Serial Monitor 115200: `$HELLO,1,temperature_plant,dev,DHT11`; then `$TTEL` lines every
   0.1 s with a sensible room temperature. LCD shows `T=..C SP=45`.
3. Type `$CFG,1,ONOFF,35,1,10,50,2000` then `$RUN,1`: the SSR input LED should light (bulb not
   connected yet). `$STOP,1` turns it off.
4. Close the enclosure, plug in mains, repeat at 35 °C, watching the first heating continuously.
5. Run the missions from `setup temperature` (T1, the heating curve, first).
