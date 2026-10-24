# Troubleshooting

First: `setup probe` in MATLAB (from the repository folder). It checks MATLAB, the toolchain,
the USB driver, the serial permission, a busy port, and asks the board for its firmware; each
problem comes with its fix. Installation per system: [install](../install/README.md).

## Computer and board

| Symptom | Cause | Fix |
|---|---|---|
| no port in the app's list | charge-only cable, hub, missing CH340 driver (Windows, old macOS), Linux permission | data cable, another socket; `setup probe` names the cause; Windows: [CH340 driver](../install/windows/README.md) |
| port appears, then vanishes (Ubuntu) | `brltty` grabs CH340 boards | `sudo apt remove brltty` |
| "port in use" | Arduino IDE Serial Monitor, another MATLAB | close it |
| connected, but no `$HELLO` within 6 s | another sketch on the board | **FLASH FIRMWARE** |
| compile fails with `bad CPU type` (Apple silicon) | the AVR compiler is an Intel binary | Rosetta 2 (`softwareupdate --install-rosetta`); the macOS installer does it |
| compile fails on Windows with odd path errors | non-ASCII user name | the toolchain goes to `C:\arduino-lab-tools` automatically; or set `TEMPLAB_TOOLS` |
| `host silent` fault | MATLAB stopped sending (frozen, closed, laptop asleep) | CLEAR FAULT, RUN again |

## The rig

| Symptom | Cause | Fix |
|---|---|---|
| SENSOR CHECK gives no reading or `nan` | DHT11 data not on D7, no pull-up, DHT22 built as DHT11 | wiring; choose the sensor before FLASH |
| the LCD stays blank or shows blocks | wrong LCD type in the build; contrast pot | choose parallel / I2C before FLASH; turn the contrast pot |
| the bulb never comes on | SSR input reversed (+ on D9, − on GND); relay needs more than 5 V input | wiring; the relay's input range on its label |
| `over-temperature` cut-off | the reading reached 70 °C | let it cool; STOP clears it; use a lower setpoint or a bigger box |
| `sensor failed` cut-off | 5 s without a valid DHT reading | wiring, the sensor; STOP clears it |
| the bulb flickers under P | PWM on pin 9 into a zero-crossing SSR | time-proportioning mode (TPROP), or accept it: it is what the course asks you to observe |
| the rig heats slower or faster than the grey line | another bulb, box or sensor position | T1 on the rig, then the physics panel until SIM matches RIG |

## Data

| Symptom | Fix |
|---|---|
| a run is missing from RUNS | runs are saved when they end, stopped or aborted ones too; see `data/RUN_REGISTER.csv` |
| SYNC DATA fails | no write access to the repository: push to your own fork |
