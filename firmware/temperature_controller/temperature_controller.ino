// Arduino temperature control lab: bulb heater, DHT11/22, SSR
// Arduino Uno + DHT11 (lab sensor; DHT22 with -DDHT_KIND=DHT22) + zero-cross SSR + 40 W bulb.
// No display on the board: the MATLAB app (temperature_lab) shows everything.
//
// Course tasks (TEMP handout SRC-015, course file SRC-001 p.17): on-off, moving average
// (N = 10 / 500 at Ts = 0.01 s), P control (Kp = 1, 2, 50, 100, 500; u = 0..255 on pin 9).
// Extra modes for the handout's Section 3: HYST (on-off with hysteresis, S3-9), STEP (bulb fully
// ON until the reading reaches the setpoint, then OFF for the rest of the run: heating and
// cooling curves for the K, tau, theta fit, S3-5) and PI (clamping anti-windup, S3-12).
// Telemetry to MATLAB / Serial Monitor with protocol v1 ($TTEL).
//
// PINS (docs/hardware/WIRING.md)
//   D7   DHT11 / DHT22 data (10 k pull-up to 5 V; most breakout modules have it)
//   D9   SSR input + (course: "relay positive terminal to PWM pin 9")
//   GND  SSR input -
//   D8   optional START / STOP pushbutton to GND (normally open)
//
// SAFETY: heater starts OFF and only runs after RUN (MATLAB) or the button.
// Hard cut-off at 60 C (DHT11; 70 C with a DHT22) or after 5 failed sensor reads in a row (10 s);
// both latch until STOP and are reported to the host ($ERR,1,RUN,12 / 13).
// Commands may be typed in the Serial Monitor without a checksum, e.g.
//   $CFG,1,P,45,1,10,50,2000      $RUN,1      $STOP,1
//   CFG fields: mode, setpoint C, hysteresis band C, MA window, Kp, TPROP window ms[, Ki per s]
//
// STATUS: compiles; runs on the PC against an emulated bulb + DHT (firmware/tests);
// NOT yet run on hardware.

#include <DHT.h>

#ifndef DHT_KIND
#define DHT_KIND DHT11            // lab sensor (owner, 2026-10-21); -DDHT_KIND=DHT22 for the other one
#endif
#define FW_NAME "temperature_lab"
#ifndef FW_REV
#define FW_REV "dev"
#endif

const uint8_t PIN_DHT = 7, PIN_SSR = 9, PIN_BTN = 8;
const uint16_t TS_MS = 10;                       // course sampling time 0.01 s
// A new reading every 2 s: the DHT11 datasheet (Aosong) asks for more than 2 s between readings,
// and the DHT library (1.4.7, MIN_INTERVAL 2000) returns its cached value to anything faster.
const uint16_t DHT_PERIOD_MS = 2000;
// Over-temperature cut-off. The DHT11 is specified for 0-50 C (+/- 2 C): 60 C lets the 55 C
// set-point run while keeping the sensor and the box out of real heat; above 50 C its readings
// are outside the datasheet. The DHT22 reads to 80 C.
const float T_CUTOFF = (DHT_KIND == DHT11) ? 60.0f : 70.0f;
const uint16_t MA_MAX = 500;                     // longest window (course: 500)
const uint8_t RUNS = 48;                         // run-length slots (see MovingAverage)
const uint8_t F_RUNNING = 1, F_SENSOR = 2, F_OVERTEMP = 4, F_WATCHDOG = 8, F_BUTTON = 16;

DHT dht(PIN_DHT, DHT_KIND);

enum Mode : uint8_t { ONOFF, HYST, MA, PCTRL, TPROP, STEP, PICTRL };
const uint8_t N_MODES = 7;
const char *MODE_NAMES[] = {"ONOFF", "HYST", "MA", "P", "TPROP", "STEP", "PI"};
struct Config {
  Mode mode = ONOFF;
  float setpoint = 45, hyst = 1.0f, Kp = 50, Ki = 0;
  uint16_t window = 10, tpropMs = 2000;
} cfg;
float piI = 0;                    // PI integral term, in output units (0..255)
bool stepDone = false;            // STEP: setpoint reached, heater latched off

// Moving average of the last N 10-ms samples, stored run-length encoded: the DHT
// value only changes every 1-2 s, so a 500-sample window holds a few runs. Exactly
// equal to a plain ring buffer while there are <= RUNS distinct runs in the window
// (always true here: 500 samples span 5 s = at most 6 DHT readings), in 192
// bytes instead of 1000. A plain int16[500] ring would leave the Uno < 300 bytes.
struct Run { int16_t v; uint16_t n; };
Run runs[RUNS]; uint8_t rHead = 0, rCount = 0; uint16_t maN = 0; int32_t maSum = 0;
static void resetFilter() { rHead = 0; rCount = 0; maN = 0; maSum = 0; }
static void maPush(int16_t v, uint16_t window) {
  uint8_t tail = (rHead + rCount + RUNS - 1) % RUNS;
  if (rCount && runs[tail].v == v) runs[tail].n++;
  else {
    if (rCount == RUNS) {                               // merge the two oldest (never expected)
      uint8_t a = rHead, b = (rHead + 1) % RUNS;
      int32_t tot = (int32_t)runs[a].v * runs[a].n + (int32_t)runs[b].v * runs[b].n;
      runs[b].n += runs[a].n; runs[b].v = tot / runs[b].n;
      maSum = maSum - tot + (int32_t)runs[b].v * runs[b].n;
      rHead = b; rCount--;
    }
    tail = (rHead + rCount) % RUNS; runs[tail].v = v; runs[tail].n = 1; rCount++;
  }
  maSum += v; maN++;
  while (maN > window) {
    runs[rHead].n--; maSum -= runs[rHead].v; maN--;
    if (runs[rHead].n == 0) { rHead = (rHead + 1) % RUNS; rCount--; }
  }
}
uint8_t badReads = 0;                            // consecutive failed DHT reads
const uint8_t SENSOR_FAIL_READS = 5;             // 5 in a row (10 s) is a sensor fault; fewer are noise
float tRaw = NAN; uint32_t lastGoodRead = 0, lastDht = 0, lastTs = 0, lastTel = 0, tStart = 0, lastHost = 0;
bool running = false, hostControlled = false, heatState = false;
uint8_t flags = 0; uint32_t seq = 0;
int u = 0; bool heaterOn = false;

// ------------------------------------------------------------------ protocol
static char hexDigit(uint8_t v) { return v < 10 ? '0' + v : 'A' + v - 10; }
static int8_t hexVal(char c) { if (c >= '0' && c <= '9') return c - '0'; if (c >= 'A' && c <= 'F') return c - 'A' + 10; if (c >= 'a' && c <= 'f') return c - 'a' + 10; return -1; }
static uint8_t xorSum(const char *s) { uint8_t x = 0; while (*s) x ^= (uint8_t)*s++; return x; }
static void sendFrame(const char *body) {
  uint8_t cs = xorSum(body);
  Serial.write('$'); Serial.print(body); Serial.write('*');
  Serial.write(hexDigit(cs >> 4)); Serial.write(hexDigit(cs & 15)); Serial.write('\n');
}
static void ack(const char *t) { char b[24]; snprintf(b, sizeof(b), "ACK,1,%s", t); sendFrame(b); }
static void err(const char *t, int code, const char *txt) { char b[64]; snprintf(b, sizeof(b), "ERR,1,%s,%d,%s", t, code, txt); sendFrame(b); }

static void heater(bool on) { heaterOn = on; digitalWrite(PIN_SSR, on ? HIGH : LOW); }
static void stopAll() { running = false; u = 0; heater(false); }


static void handleLine(char *line) {
  if (line[0] != '$') return;
  char *star = strrchr(line, '*');
  if (star) { *star = 0; if (xorSum(line + 1) != (uint8_t)((hexVal(star[1]) << 4) | hexVal(star[2]))) { err("?", 1, "checksum"); return; } }
  char *tok[10]; uint8_t nt = 0;
  for (char *p = strtok(line + 1, ","); p && nt < 10; p = strtok(NULL, ",")) tok[nt++] = p;
  if (nt < 2 || strcmp(tok[1], "1")) { err("?", 2, "version"); return; }
  const char *t = tok[0];
  lastHost = millis();
  if (!strcmp(t, "PING")) return;
  if (!strcmp(t, "CFG")) {
    if (running) { err(t, 3, "stop first"); return; }
    if (nt != 8 && nt != 9) { err(t, 4, "fields"); return; }
    uint8_t m = 255;
    for (uint8_t i = 0; i < N_MODES; i++) if (!strcmp(tok[2], MODE_NAMES[i])) m = i;
    if (m == 255) { err(t, 5, "mode"); return; }
    cfg.mode = (Mode)m; cfg.setpoint = atof(tok[3]); cfg.hyst = atof(tok[4]);
    cfg.window = constrain(atoi(tok[5]), 1, MA_MAX); cfg.Kp = atof(tok[6]); cfg.tpropMs = constrain(atol(tok[7]), 200, 60000);
    cfg.Ki = (nt == 9) ? atof(tok[8]) : 0;
    if (cfg.setpoint > T_CUTOFF - 5) cfg.setpoint = T_CUTOFF - 5;
    ack(t); return;
  }
  if (!strcmp(t, "SET")) { if (nt == 3) { cfg.setpoint = min(atof(tok[2]), T_CUTOFF - 5); ack(t); } else err(t, 4, "fields"); return; }
  if (!strcmp(t, "RUN")) {
    if (flags & (F_OVERTEMP | F_SENSOR)) { err(t, 6, "fault latched: STOP first"); return; }
    running = true; hostControlled = true; seq = 0; tStart = millis(); resetFilter(); heatState = false;
    piI = 0; stepDone = false; ack(t); return;
  }
  if (!strcmp(t, "STOP") || !strcmp(t, "ESTOP")) { stopAll(); flags = 0; ack(t); return; }
  err(t, 7, "unknown");
}

static void pollHost() {
  static char buf[80]; static uint8_t n = 0;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\r') continue;
    if (c == '\n') { buf[n] = 0; if (n) handleLine(buf); n = 0; }
    else if (n < sizeof(buf) - 1) buf[n++] = c; else n = 0;
  }
}

// ------------------------------------------------------------------ control
static void controlStep(uint32_t now) {
  // moving average over the last N 10-ms samples of the latest reading
  int16_t s = isnan(tRaw) ? 0 : (int16_t)lround(tRaw * 10);
  maPush(s, cfg.window);
  float tFilt = maSum / (10.0f * maN);

  if (!running || isnan(tRaw)) { u = 0; heater(false); return; }
  float e = cfg.setpoint - tRaw;
  switch (cfg.mode) {
    case ONOFF: u = (tRaw < cfg.setpoint) ? 255 : 0; heater(u); break;
    case HYST:
      if (tRaw < cfg.setpoint - cfg.hyst / 2) heatState = true;
      else if (tRaw > cfg.setpoint + cfg.hyst / 2) heatState = false;
      u = heatState ? 255 : 0; heater(heatState); break;
    case MA: u = (tFilt < cfg.setpoint) ? 255 : 0; heater(u); break;
    case PCTRL:
      u = constrain((int)lround(cfg.Kp * e), 0, 255);
      analogWrite(PIN_SSR, u); heaterOn = u > 0; break;     // course wiring: PWM into the SSR
    case TPROP: {
      u = constrain((int)lround(cfg.Kp * e), 0, 255);
      uint32_t ph = (now - tStart) % cfg.tpropMs;
      heater(ph < (uint32_t)u * cfg.tpropMs / 255); break;
    }
    case STEP:                                         // open-loop heating, then cooling
      if (tRaw >= cfg.setpoint) stepDone = true;
      u = stepDone ? 0 : 255; heater(u); break;
    case PICTRL: {
      // u = Kp e + I, I += Ki Ts e, output 0..255. Clamping anti-windup: when the output is at
      // a limit and the error pushes further into it, the integral is not advanced.
      float iNew = piI + cfg.Ki * (TS_MS / 1000.0f) * e;
      float uRaw = cfg.Kp * e + iNew;
      bool satHi = uRaw > 255, satLo = uRaw < 0;
      if (!((satHi && e > 0) || (satLo && e < 0))) piI = iNew;
      u = constrain((int)lround(cfg.Kp * e + piI), 0, 255);
      analogWrite(PIN_SSR, u); heaterOn = u > 0; break;
    }
  }
  (void)tFilt;
}

static void sendTelemetry(uint32_t now) {
  char sp[10], tr[10], tf[10], er[10];
  float tFilt = maN ? maSum / (10.0f * maN) : NAN;
  if (isnan(tRaw)) strcpy(tr, "nan"); else dtostrf(tRaw, 1, 1, tr);
  if (isnan(tFilt)) strcpy(tf, "nan"); else dtostrf(tFilt, 1, 2, tf);
  dtostrf(cfg.setpoint, 1, 1, sp);
  if (isnan(tRaw)) strcpy(er, "nan"); else dtostrf(cfg.setpoint - tRaw, 1, 2, er);
  char body[110];
  snprintf(body, sizeof(body), "TTEL,1,%lu,%lu,%s,%s,%s,%s,%s,%d,%d,%X",
           (unsigned long)seq++, (unsigned long)(now - tStart), MODE_NAMES[cfg.mode], sp, tr, tf, er, u,
           heaterOn ? 1 : 0, flags | (running ? F_RUNNING : 0));
  sendFrame(body);
}

void setup() {
  pinMode(PIN_SSR, OUTPUT); heater(false);
  pinMode(PIN_BTN, INPUT_PULLUP);
  Serial.begin(115200);
  dht.begin();
  char b[48]; snprintf(b, sizeof(b), "HELLO,1,%s,%s,%s", FW_NAME, FW_REV, DHT_KIND == DHT11 ? "DHT11" : "DHT22"); sendFrame(b);
  Serial.println(F("# commands: $CFG,1,<ONOFF|HYST|MA|P|TPROP|STEP|PI>,sp,hyst,N,Kp,tpropMs[,Ki]  $RUN,1  $STOP,1"));
  lastGoodRead = millis();
}

void loop() {
  pollHost();
  uint32_t now = millis();
  // button: toggle run (standalone use without MATLAB)
  static bool lastBtn = HIGH; static uint32_t tBtn = 0;
  bool b = digitalRead(PIN_BTN);
  if (b != lastBtn && now - tBtn > 50) {
    tBtn = now; lastBtn = b;
    if (b == LOW) {
      if (running) { stopAll(); flags |= F_BUTTON; }
      else if (!(flags & (F_OVERTEMP | F_SENSOR))) { running = true; hostControlled = false; tStart = now; seq = 0; resetFilter(); flags = 0; }
      else { flags = 0; }                                     // second press clears a latched fault
    }
  }
  if (now - lastDht >= DHT_PERIOD_MS) {
    lastDht = now;
    float v = dht.readTemperature();
    if (!isnan(v)) { tRaw = v; lastGoodRead = now; badReads = 0; }
    else {
      // a DHT11 read fails now and then (timing or checksum); the last good value stands
      if (badReads < 255) badReads++;
      Serial.print(F("# DHT read failed, ")); Serial.print(badReads); Serial.println(F(" in a row"));
    }
    if (badReads >= SENSOR_FAIL_READS) {
      tRaw = NAN;
      if (running) { stopAll(); flags |= F_SENSOR; err("RUN", 12, "sensor: no valid reading for 10 s - heater off"); }
    }
    if (!isnan(tRaw) && tRaw >= T_CUTOFF && !(flags & F_OVERTEMP)) {
      bool was = running; stopAll(); flags |= F_OVERTEMP;
      if (was) err("RUN", 13, "over-temperature cut-off - heater off");
    }
  }
  if (running && hostControlled && now - lastHost > 3000) { stopAll(); flags |= F_WATCHDOG; err("RUN", 10, "host silent >3 s - heater off"); }
  if (now - lastTs >= TS_MS) { lastTs += TS_MS; if (now - lastTs > TS_MS) lastTs = now; controlStep(now); }
  if (now - lastTel >= 100) { lastTel = now; sendTelemetry(now); }         // 10 Hz telemetry
}
