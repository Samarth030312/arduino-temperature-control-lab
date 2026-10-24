# The sequence: everything, in order

## Without hardware

**1. Set up.** In MATLAB:

```matlab
gitclone("https://github.com/Samarth030312/arduino-temperature-control-lab.git", Depth=1);
cd arduino-temperature-control-lab
setup open
```

**2. The plant (T1).** Play the heating curve; read K, τ and θ in the table and on the plot.
Change the bulb rating, the box size and the wall loss in the physics panel and predict, before
you play, what each does to K and τ. Read: [first principles](FIRST_PRINCIPLES.md).

**3. On-off and its variants (T2–T4).** Play each preset; watch the band, the switching rate and
the bulb in the 3-D view. Before T4, predict what N = 10 will change.

**4. P, PI, PID (T5, T6).** Compare the steady error with the REF column (the formula); push Kp
until P behaves like on-off.

**5. Disturbance and saturation (T7, T8).** Who recovers from the room cooling; what a limited
heater does to an integrator, with and without anti-windup.

**6. Simulink.** **OPEN IN SIMULINK** on any mission. Read: [Simulink](SIMULINK.md).

## With the rig

**7. Build and wire** ([replicate](REPLICATE.md)), [checklist](safety/EXPERIMENT_CHECKLIST.md).

**8. Flash and connect**, SENSOR CHECK.

**9. T1 on the rig**, then fit your box: physics panel until SIM matches RIG.

**10. T2 → T8 on the rig.** Every run lands in `data/raw/temperature/` and `data/RUN_REGISTER.csv`;
RUNS → OVERLAY RUN draws it over the simulation of its own settings.
