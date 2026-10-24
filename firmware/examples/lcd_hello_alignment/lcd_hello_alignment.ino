// ENR312 TEMP handout, Section 2 Q9: show "Hello" on a 16x2 LCD at the six positions
// (line 1 / line 2 x left / centre / right), two seconds each, forever.
//
// Column of the first character for a text of length n on a 16-column display:
//   left = 0, centre = (16 - n) / 2, right = 16 - n          ("Hello": 0, 5, 11)
// Wiring as the temperature experiment (docs/wiring/TEMPERATURE_WIRING.md):
//   parallel LCD: RS D12, E D11, D4 D5, D5 D4, D6 D3, D7 D2 (+ contrast pot on V0)
//   or I2C backpack: SDA A4, SCL A5, compile with -DLCD_I2C (address 0x27; some modules use 0x3F)
#ifdef LCD_I2C
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
LiquidCrystal_I2C lcd(0x27, 16, 2);
#else
#include <LiquidCrystal.h>
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
#endif

const char *TEXT = "Hello";
const uint8_t COLS = 16;

void show(uint8_t row, uint8_t col, const char *where) {
  lcd.clear();
  lcd.setCursor(col, row);                 // setCursor(column, row), both counted from 0
  lcd.print(TEXT);
  Serial.print(F("row ")); Serial.print(row + 1); Serial.print(F(" ")); Serial.print(where);
  Serial.print(F(": column ")); Serial.println(col);
  delay(2000);
}

void setup() {
  Serial.begin(115200);
#ifdef LCD_I2C
  lcd.init(); lcd.backlight();
#else
  lcd.begin(COLS, 2);
#endif
}

void loop() {
  uint8_t n = strlen(TEXT);
  for (uint8_t row = 0; row < 2; row++) {
    show(row, 0, "left");
    show(row, (COLS - n) / 2, "centre");
    show(row, COLS - n, "right");
  }
}
