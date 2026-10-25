// Runs the real temperature firmware (temperature_controller.ino) on the PC against an emulated
// bulb + DHT11, drives it like MATLAB would, and checks the behaviour of every mode.
//
//   scripts/validation/build_firmware.sh        (builds and runs this)
//
// The emulated plant is a test double (first-order thermal lag, 1 C DHT11 steps), not a model
// of the real bulb. Writes the serial output to argv[1] for the MATLAB transcript test.

#include "Arduino.h"
#include <algorithm>
#include <string>
#include <chrono>
#include <thread>
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>

double g_now_ms = 0;
static bool g_realtime = false;                 // --pty mode: real wall-clock time
static double wallMs() {
  using namespace std::chrono;
  static auto t0 = steady_clock::now();
  return duration<double, std::milli>(steady_clock::now() - t0).count();
}
uint32_t millis() { if (g_realtime) g_now_ms = wallMs(); return (uint32_t)g_now_ms; }
uint32_t micros() { millis(); return (uint32_t)(g_now_ms * 1000.0); }
void delay(unsigned long ms) {
  if (g_realtime) { std::this_thread::sleep_for(std::chrono::milliseconds(ms)); g_now_ms = wallMs(); return; }
  g_now_ms += ms;
}
static int g_pin[20], g_pwm[20];
void pinMode(uint8_t p, uint8_t m) { if (m == INPUT_PULLUP) g_pin[p] = HIGH; }
void digitalWrite(uint8_t p, uint8_t v) { g_pin[p] = v; g_pwm[p] = v ? 255 : 0; }
int digitalRead(uint8_t p) { return g_pin[p]; }
void analogWrite(uint8_t p, int v) { g_pwm[p] = v; g_pin[p] = v > 0; }
char *dtostrf(double v, signed char w, unsigned char p, char *b) { sprintf(b, "%*.*f", w, p, v); return b; }
HostSerial Serial;
float g_dhtValue = 30; bool g_dhtFail = false;

// ------------------------------------------------------------------ emulated bulb + sensor
struct Plant {
  double T = 30, Tamb = 30;         // C
  double K = 54, tau = 150;         // full power: +54 C, 150 s (the simulation's estimates)
  int switches = 0; bool lastOn = false;
  void step(double dt_s, int pwm) {  // pwm: 0..255 on pin 9 (digitalWrite -> 0/255)
    double frac = pwm / 255.0;
    T += dt_s / tau * (Tamb + K * frac - T);
    bool on = pwm > 0; if (on != lastOn) switches++; lastOn = on;
    g_dhtValue = (float)std::round(T);   // DHT11: 1 C resolution
  }
} plant;

#include "../temperature_controller/temperature_controller.ino"

static void send(const std::string &body) {
  uint8_t x = 0; for (char c : body) x ^= (uint8_t)c;
  char t[4]; snprintf(t, sizeof t, "%02X", x);
  for (char c : "$" + body + "*" + t + "\n") Serial.in.push_back(c);
}
static void runFor(double s, bool ping = true) {
  double end = g_now_ms + s * 1000, nextPing = g_now_ms;
  while (g_now_ms < end) {
    if (ping && g_now_ms >= nextPing) { send("PING,1"); nextPing += 1000; }
    loop();
    g_now_ms += 1;
    plant.step(0.001, g_pwm[PIN_SSR]);
  }
}
static int fails = 0;
#define CHECK(cond, msg) do { if (cond) printf("  ok    %s\n", msg); else { printf("  FAIL  %s\n", msg); fails++; } } while (0)
static double lastField(int idx) {               // field idx (0-based after the version) of the last $TTEL
  size_t p = Serial.out.rfind("$TTEL,1,"); if (p == std::string::npos) return NAN;
  std::string l = Serial.out.substr(p + 8, Serial.out.find('*', p) - p - 8);
  for (int i = 0; i < idx; i++) l = l.substr(l.find(',') + 1);
  return atof(l.c_str());
}
static void reset(double T) { send("STOP,1"); runFor(0.2, false); plant.T = T; plant.switches = 0; runFor(1.5, false); }

// --pty [speedup]: run the firmware in real time on a pseudo-terminal so MATLAB can connect to it
// (end-to-end test of temperature_lab <-> real firmware code <-> emulated bulb). The firmware keeps
// real time (its 3 s watchdog is real); the bulb's thermal time runs `speedup` times faster.
static int runPty(double speedup) {
  g_realtime = true;
  int m = posix_openpt(O_RDWR | O_NOCTTY);
  if (m < 0 || grantpt(m) || unlockpt(m)) { perror("pty"); return 2; }
  fcntl(m, F_SETFL, O_NONBLOCK);
  int sl = open(ptsname(m), O_RDWR | O_NOCTTY);
  struct termios tio; tcgetattr(sl, &tio); cfmakeraw(&tio); tcsetattr(sl, TCSANOW, &tio);
  printf("PTY %s\n", ptsname(m)); fflush(stdout);
  setup();
  double lastHello = wallMs(), last = wallMs(); bool heard = false;
  for (;;) {
    char b[256]; ssize_t n = read(m, b, sizeof b);
    for (ssize_t i = 0; i < n; i++) Serial.in.push_back(b[i]);
    if (n > 0) heard = true;
    if (!heard && wallMs() - lastHello > 1000) { setup(); lastHello = wallMs(); }
    loop();
    double now = wallMs(); plant.step(speedup * (now - last) / 1000.0, g_pwm[PIN_SSR]); last = now;
    if (!Serial.out.empty()) { ssize_t w = write(m, Serial.out.data(), Serial.out.size()); if (w > 0) Serial.out.erase(0, w); }
    std::this_thread::sleep_for(std::chrono::microseconds(500));
  }
}

int main(int argc, char **argv) {
  if (argc > 1 && std::string(argv[1]) == "--pty") return runPty(argc > 2 ? atof(argv[2]) : 1.0);
  printf("temperature firmware host test (emulated bulb, DHT11)\n");
  setup(); runFor(3, false);                            // the first reading comes 2 s after start
  CHECK(Serial.out.find("$HELLO,1,temperature_lab,dev,DHT11*") != std::string::npos, "HELLO reports the DHT11 build");
  CHECK(g_pwm[PIN_SSR] == 0, "heater OFF after power-up");
  CHECK(Serial.out.find("$TTEL,1,") != std::string::npos, "telemetry flows after power-up (the app is the display)");

  // ON-OFF at 45 C: reaches the band and switches; never above the cut-off
  send("CFG,1,ONOFF,45,1,10,50,2000"); send("RUN,1"); runFor(600);
  CHECK(plant.T > 43 && plant.T < 48, "ON-OFF holds ~45 C");
  int swOnOff = plant.switches;
  printf("        ON-OFF: %d heater switches in 600 s\n", swOnOff);
  CHECK(lastField(7) == 0 || lastField(7) == 255, "ON-OFF output is 0 or 255");

  // hysteresis 1 C band switches less often than plain ON-OFF
  reset(45); send("CFG,1,HYST,45,1,10,50,2000"); send("RUN,1"); runFor(600);
  printf("        HYST 1 C: %d switches\n", plant.switches);
  CHECK(plant.switches < swOnOff, "hysteresis reduces switching");

  // moving average, N = 500 (5 s at 10 ms): filtered value lags the raw reading
  reset(30); send("CFG,1,MA,45,1,500,50,2000"); send("RUN,1"); runFor(120);
  CHECK(lastField(5) < lastField(4) + 0.01, "MA(500) filtered value lags the rising raw value");
  CHECK(Serial.out.find(",MA,") != std::string::npos, "MA mode reported in telemetry");

  // P control, Kp = 2: steady error ~ (45 - 30) / (1 + K Kp / 255) with K = 54
  reset(30); send("CFG,1,P,45,1,10,2,2000"); send("RUN,1"); runFor(900);
  double eP = 45 - plant.T, ePred = 15.0 / (1 + 54.0 * 2 / 255);
  printf("        P Kp 2: e = %.2f C (theory %.2f C)\n", eP, ePred);
  CHECK(fabs(eP - ePred) < 1.5, "P control leaves the predicted steady-state error");
  CHECK(lastField(7) == std::min(255.0, std::max(0.0, std::round(2 * lastField(6)))), "u = Kp e, clamped 0..255");

  // PI removes the error; the integral never winds beyond the 0..255 output
  reset(30); send("CFG,1,PI,45,1,10,2,2000,0.05"); send("RUN,1"); runFor(1500);
  printf("        PI Kp 2 Ki 0.05: T = %.2f C, u = %.0f\n", plant.T, lastField(7));
  CHECK(fabs(plant.T - 45) < 1.0, "PI reaches 45 C (no steady-state error)");
  CHECK(piI <= 255.5 && piI >= -0.5, "PI integral stays inside the output range (anti-windup)");

  // STEP: full power until the reading reaches the setpoint, then off for good (cooling curve)
  reset(30); send("CFG,1,STEP,50,1,10,50,2000"); send("RUN,1");
  for (int i = 0; i < 400 && !stepDone; i++) runFor(1);
  CHECK(stepDone && g_pwm[PIN_SSR] == 0, "STEP heats to 50 C then latches the heater off");
  double Tpeak = plant.T; runFor(200);
  CHECK(g_pwm[PIN_SSR] == 0, "STEP: heater stays off while cooling");
  CHECK(plant.T < Tpeak - 5, "STEP: temperature falls after the switch-off (cooling recorded)");

  // safety: over-temperature cut-off (60 C with the DHT11) latches until STOP; 55 C still runs
  reset(30); plant.K = 80; send("CFG,1,ONOFF,55,1,10,50,2000"); send("RUN,1");
  g_dhtFail = false; plant.T = 58; runFor(3);               // (until the next reading the bulb may still heat)
  CHECK(running && !(flags & F_OVERTEMP), "58 C: below the cut-off, the 55 C set-point can run");
  plant.T = 61; runFor(3);
  CHECK(!running && (flags & F_OVERTEMP) && g_pwm[PIN_SSR] == 0, "60 C cut-off: heater off and latched");
  CHECK(Serial.out.find("$ERR,1,RUN,13,") != std::string::npos, "the cut-off is reported to the host");
  send("RUN,1"); runFor(0.2);
  CHECK(Serial.out.find("fault latched") != std::string::npos, "RUN refused while the cut-off is latched");
  plant.K = 54;

  // sensor: a failed read now and then is noise (seen on the lab DHT11, 2026-10-26); 5 failed
  // reads in a row (10 s) is a fault, reported to the host
  reset(30); send("CFG,1,ONOFF,45,1,10,50,2000"); send("RUN,1"); runFor(5);
  for (int k = 0; k < 10; k++) { g_dhtFail = (k % 2 == 0); runFor(2); }
  g_dhtFail = true; runFor(7.9);                             // 4 failed reads in a row
  CHECK(running && !(flags & F_SENSOR), "occasional failed reads, and 4 in a row: still running");
  CHECK(Serial.out.find("# DHT read failed, 4 in a row") != std::string::npos, "each failed read is reported");
  size_t m0 = Serial.out.size(); runFor(4);
  CHECK(!running && (flags & F_SENSOR) && g_pwm[PIN_SSR] == 0, "5 failed reads in a row (10 s): heater off");
  CHECK(Serial.out.find("$ERR,1,RUN,12,", m0) != std::string::npos, "the sensor fault is reported to the host");
  g_dhtFail = false;

  // host watchdog: MATLAB silent for 3 s -> heater off
  reset(30); send("CFG,1,ONOFF,45,1,10,50,2000"); send("RUN,1"); runFor(2);
  runFor(4, false);
  CHECK(!running && g_pwm[PIN_SSR] == 0 && Serial.out.find("host silent") != std::string::npos, "host watchdog: heater off after 3 s");

  // CFG validation
  send("STOP,1"); send("CFG,1,BOGUS,45,1,10,50,2000"); runFor(0.1, false);
  CHECK(Serial.out.find("ERR,1,CFG,5,mode") != std::string::npos, "unknown mode refused");
  send("CFG,1,ONOFF,45"); runFor(0.1, false);
  CHECK(Serial.out.find("ERR,1,CFG,4,fields") != std::string::npos, "short CFG refused");

  if (argc > 1) {                       // fixture: every non-telemetry line + every 20th $TTEL (size)
    FILE *f = fopen(argv[1], "w"); size_t p = 0; long n = 0;
    while (p < Serial.out.size()) {
      size_t q = Serial.out.find('\n', p); if (q == std::string::npos) q = Serial.out.size();
      std::string l = Serial.out.substr(p, q - p);
      if (l.rfind("$TTEL", 0) != 0 || n++ % 20 == 0) fprintf(f, "%s\n", l.c_str());
      p = q + 1;
    }
    fclose(f); printf("  transcript -> %s\n", argv[1]);
  }
  printf(fails ? "temperature firmware host test: %d FAILED\n" : "temperature firmware host test: all passed\n", fails);
  return fails != 0;
}
