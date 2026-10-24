// DHT library stub: the test's emulated bulb sets the reading.
#pragma once
#define DHT11 11
#define DHT22 22
extern float g_dhtValue; extern bool g_dhtFail;
class DHT {
 public:
  DHT(uint8_t, uint8_t) {}
  void begin() {}
  float readTemperature() { return g_dhtFail ? NAN : g_dhtValue; }
};
