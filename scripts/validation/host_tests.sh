#!/usr/bin/env bash
# Firmware tests on the PC (g++ only, no Arduino toolchain): the real sketch runs against an
# emulated plant; its output is the protocol transcript the MATLAB tests parse. The build is
# also the real-time emulator (--pty) the end-to-end test talks to.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# the moving average is tested on the sketch's own code: extract maPush and its state from it
python3 - "$root/firmware/temperature_controller/temperature_controller.ino" "$tmp/ma_extracted.inc" <<'PY'
import sys
s = open(sys.argv[1]).read()
i = s.index('struct Run {'); j = s.index('\n}\n', s.index('static void maPush')) + 3
open(sys.argv[2], 'w').write(s[i:j])
PY
g++ -std=c++17 -O1 -I"$tmp" -o "$tmp/tma" "$root/firmware/tests/test_moving_average.cpp"
"$tmp/tma"
echo "== temperature firmware against an emulated bulb, box and DHT11"
g++ -std=c++17 -O1 -w -include algorithm -I"$root/firmware/tests/host_stubs" -o "$root/firmware/tests/tempsim" "$root/firmware/tests/firmware_host_test.cpp"
"$root/firmware/tests/tempsim" "$root/firmware/tests/fixtures/temperature_transcript.txt"
