# Sourced by the scripts in scripts/setup and scripts/validation (bash, Linux and macOS).
# Same folders as templab.tools.paths in MATLAB; TEMPLAB_TOOLS overrides the default.
#   TEMPLAB_ROOT   repository root
#   TEMPLAB_CLI    arduino-cli executable of this project
# and exports the ARDUINO_DIRECTORIES_* variables, so arduino-cli and the Arduino IDE
# use this project's own cores and libraries (the global ~/.arduino15 is never touched).
TEMPLAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -z "${TEMPLAB_TOOLS:-}" ]; then
  case "$(uname -s)" in
    Darwin) TEMPLAB_TOOLS="$HOME/Library/Application Support/arduino-lab-tools" ;;
    *) TEMPLAB_TOOLS="$HOME/.local/share/arduino-lab-tools" ;;
  esac
fi
TEMPLAB_CLI="$TEMPLAB_TOOLS/arduino-cli/arduino-cli"
export ARDUINO_DIRECTORIES_DATA="$TEMPLAB_TOOLS/arduino/data"
export ARDUINO_DIRECTORIES_DOWNLOADS="$TEMPLAB_TOOLS/arduino/downloads"
export ARDUINO_DIRECTORIES_USER="$TEMPLAB_TOOLS/arduino/user"
export ARDUINO_UPDATER_ENABLE_NOTIFICATION=false
