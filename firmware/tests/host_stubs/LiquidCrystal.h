// LCD stub: remembers what was printed on each line.
#pragma once
#include <string>
extern std::string g_lcd[2];
class LiquidCrystal {
  int row = 0, col = 0;
 public:
  LiquidCrystal(int, int, int, int, int, int) {}
  void begin(int, int) {}
  void setCursor(int c, int r) { col = c; row = r; }
  void clear() { g_lcd[0] = g_lcd[1] = std::string(16, ' '); }
  void print(const char *s) { std::string &l = g_lcd[row]; if (l.size() < 16) l.resize(16, ' '); for (; *s && col < 16; s++) l[col++] = *s; }
};
