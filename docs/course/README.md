# Course guide: ENR312 Control Systems Laboratory (Ahmedabad University)

This repository is one apparatus of the ENR312 control laboratory. Everything in it is general;
this page maps the course handout onto the parts of the repository that let you **do** each task
and **find** each answer yourself. It does not give the answers: the models, the rig and your
data do.

## Before the lab

Install and open the app ([the sequence](../SEQUENCE.md), the steps without hardware); play each
mission once. Write down what you expect the rig to do before you see it.

## The handout, task by task

| Handout | Mission in the app | What to look at |
|---|---|---|
| Section 1, tasks 1–3: parts, IDE, reading the temperature | SENSOR CHECK, any mission on the rig | [wiring](../hardware/WIRING.md); the reading on the LCD, in the app and in the Serial Monitor |
| task 4: on-off at 35, 45, 55 °C; flicker | T2 | band, switches per minute, the bulb in 3-D |
| task 5: moving average, Ts = 10 ms, N = 10 and 500 | T4 | what N × 10 ms is, against the sensor's update |
| task 6: the error; P with Kp = 1, 2, 50, 100, 500 | T5 | the steady error against the REF column; the bulb at large Kp |
| S3-1 the sensor's range, resolution, accuracy, period | — | the DHT11's datasheet; the 1 °C staircase in every plot |
| S3-2, S3-3 the moving-average window, delay, overshoot | T4 | the window's span in seconds, the number of distinct readings in it |
| S3-4 on-off swing and period | T2 | read them off the plot and the table |
| S3-5 K, τ, θ from the heating curve; heating against cooling | T1 | the fit in the table; compare the two halves of the curve |
| S3-6 PWM into a zero-crossing SSR | T5 (SSR drive: as wired) | the bulb's pattern; [first principles §4](../FIRST_PRINCIPLES.md#4-control-laws-and-what-to-expect) |
| S3-7 the controller's output for a given error; saturation | T5 | u = Kp e and its 0–255 limit |
| S3-8 Simulink with K, τ, θ, 1 °C, 1 s | OPEN IN SIMULINK | [Simulink](../SIMULINK.md) |
| S3-9 hysteresis | T3 | band and switches per minute against T2 |
| S3-10 P's steady error, derived and simulated | T5 | the REF column holds the formula's value |
| S3-11 limit cycle and dead time | T2 with the physics panel's θ | how the swing grows with θ |
| S3-12 PI with clamping | T6, T8 | ANTI-WINDUP on and off |

## The lab report

The course asks for a summary of the tasks, a description of what you did, your programs, the
answers to the Section 2 and Section 3 questions, screenshots of simulation inputs and outputs,
and a comparison of simulation and hardware with its advantages and limitations. Every rig run
is saved and numbered in `data/RUN_REGISTER.csv`: cite run ids for every hardware number.
