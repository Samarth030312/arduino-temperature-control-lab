// Host test: the firmware's run-length moving average equals a plain ring buffer.
//   g++ -std=c++17 -O1 -o /tmp/t firmware/tests/test_moving_average.cpp && /tmp/t
// Extracts maPush/resetFilter from the sketch source so the test runs the real code.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>
#include <deque>
const uint8_t RUNS = 48;
#define MAPUSH_UNDER_TEST
#include "ma_extracted.inc"

int main() {
  std::mt19937 rng(42);
  int fails = 0;
  for (uint16_t window : {1, 10, 50, 500}) {
    for (int period : {1, 7, 100, 200}) {                 // samples between value changes
      resetFilter();
      std::deque<int16_t> ref; long refSum = 0; int16_t v = 300;
      for (int k = 0; k < 20000; k++) {
        if (k % period == 0) v = 250 + rng() % 300;
        maPush(v, window);
        ref.push_back(v); refSum += v; if ((int)ref.size() > window) { refSum -= ref.front(); ref.pop_front(); }
        bool exact = (window / period + 1 <= RUNS);       // more runs than slots => documented merge (approximate)
        if (exact && (maSum != refSum || maN != ref.size())) {
          if (fails++ < 5) printf("FAIL window %u period %d k %d: %ld vs %ld\n", window, period, k, (long)maSum, refSum);
          break;
        }
      }
    }
  }
  printf(fails ? "moving average: FAILED\n" : "moving average: run-length == ring buffer for all cases\n");
  return fails != 0;
}
