# Third-party components

Nothing below is redistributed in this repository. The installers fetch each component
from its official source at the pinned version, into a tool folder of your user account.

| Component | Version | Licence | Used by |
|---|---|---|---|
| [Arduino CLI](https://github.com/arduino/arduino-cli) | 1.5.1 | GPL-3.0 (tool, not linked) | compile and upload the firmware |
| [Arduino AVR core](https://github.com/arduino/ArduinoCore-avr) (`arduino:avr`) | 1.8.8 | LGPL-2.1 | every sketch (Uno) |
| [DHT sensor library](https://github.com/adafruit/DHT-sensor-library) (Adafruit) | 1.4.7 | MIT | DHT11 |
| [Adafruit Unified Sensor](https://github.com/adafruit/Adafruit_Sensor) | 1.1.15 | Apache-2.0 | dependency of the DHT library |
| [LiquidCrystal](https://github.com/arduino-libraries/LiquidCrystal) (Arduino, Adafruit) | 1.0.7 | LGPL-2.1 or later | parallel 16x2 LCD |
| [LiquidCrystal I2C](https://github.com/marcoschwartz/LiquidCrystal_I2C) (Frank de Brabander) | 1.1.2 | none stated in the distributed library | I2C 16x2 LCD (optional) |

MATLAB and Simulink (MathWorks) are required to run the apps and models and are not part
of this repository; the [CI](.github/workflows/ci.yml) uses MathWorks' free licensing for
public projects on GitHub-hosted runners.

Not included and not redistributed: the ENR312 course handouts and the sensor, relay and LCD datasheets. They are cited in
[`docs/knowledge-base/SOURCE_REGISTER.csv`](docs/knowledge-base/SOURCE_REGISTER.csv).
