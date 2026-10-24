# How it works

Four things can run the same experiment: the **simulator** in the app, the **Simulink**
model, the **emulator** (the real firmware compiled for the PC), and the **rig**.

## The loop

```mermaid
flowchart LR
    SP["setpoint °C"] --> E(("−"))
    E --> C["Arduino Uno, every 10 ms<br/>on-off · hysteresis · moving average<br/>P · PI · time-proportioning"]
    C -->|"D9: 0-255"| SSR["SSR-40DA<br/>zero-cross: whole mains half-cycles"]
    SSR --> B["bulb: heat η·P"]
    B --> Z["air and structure in the box<br/>C dT/dt = ηPu − (T − T_room)/R"]
    Z -->|"3 s from bulb to sensor"| D["DHT11: 1 °C steps,<br/>new value once a second, its own lag"]
    D -.->|"D7"| E
```

Three things make this plant interesting for control, all of them in the model:

- **It is slow and can only heat.** Cooling is the room's job; the controller's output is 0 to
  full power, never negative.
- **The sensor is coarse and late.** The DHT11 gives whole degrees, refreshed once a second,
  behind its own thermal lag. A controller running every 10 ms mostly sees the same number.
- **The actuator is a mains switch.** A zero-crossing SSR can only pass whole half-cycles, so a
  fast PWM on pin 9 becomes a flicker of the bulb, not a smooth power. Time-proportioning
  (on for a fraction of a 2 s window) gives the same average power without the flicker.

## Four ways to run one experiment

| | What it is | Use it to |
|---|---|---|
| **Simulator** | MATLAB, inside the app: the bulb and box from the physics panel, the DHT11's lag, update and resolution, the SSR's average power, and the firmware's controller laws | learn the concepts without hardware; predict a rig run |
| **Simulink** | `temperature_plant.slx`, generated from code; **OPEN IN SIMULINK** builds it with the app's settings | see and change the block diagram ([Simulink](SIMULINK.md)) |
| **Emulator** | the sketch compiled with g++ against an emulated bulb, box and DHT11, in real time on a pseudo-terminal (faster than real time on request) | test the firmware and the app together without a rig; CI does |
| **Rig** | the Uno, the SSR, the bulb in its box, the DHT11, the LCD | measure |

## A run, from button to file

```mermaid
sequenceDiagram
    participant App as app (MATLAB)
    participant Uno as Arduino Uno
    App->>Uno: $CFG mode, setpoint, band, N, Kp, window, Ki
    App->>Uno: $RUN
    loop every 10 ms
        Uno->>Uno: read the DHT11 (new value once a second), control law, D9
        Uno-->>App: $TTEL every 0.1 s: setpoint, reading, heater, flags
        App-->>Uno: $PING
    end
    App->>Uno: $STOP (bulb off)
    App->>App: data/raw/temperature/TEMP-Rnnnn_….csv, metadata, RUN_REGISTER.csv
```

Safety in the firmware, independent of the PC: the bulb starts off and runs only after RUN (or
the button on D8); a hard cut-off at 70 °C; a cut-off after 5 s without a valid sensor reading;
the bulb off if the PC is silent for 3 s. Protocol: [serial protocol](architecture/SERIAL_PROTOCOL.md).
