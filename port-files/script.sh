#!/bin/sh
# Insaniquarium Deluxe on the Miyoo Mini (Onion).
#
# Everything goes to log.txt so a failure can be read from a PC afterwards: the
# .port goes through launch_standalone.sh, which does not redirect.
GAMEDIR="/mnt/SDCARD/Roms/PORTS/Games/Insaniquarium"
LOG="$GAMEDIR/log.txt"
cd "$GAMEDIR" || exit 1

exec > "$LOG" 2>&1

echo "=== Insaniquarium launcher ==="
date
uname -a

# love-mmiyoo's rules: prefix LD_LIBRARY_PATH (never replace it, Onion preloads
# /config/lib), and drop libpadsp -- it hooks fb0 and the audio path, and this
# port uses neither through it.
export LD_LIBRARY_PATH="$GAMEDIR/lib:${LD_LIBRARY_PATH:-/lib:/config/lib:/mnt/SDCARD/miyoo/lib}"
export LD_PRELOAD=/mnt/SDCARD/miyoo/lib/libpadsp.so
echo "LD_PRELOAD=[${LD_PRELOAD:-}]"

# The SDL2 that works on this device: love-mmiyoo's, with the evdev driver. It
# supplies the window and input; the picture is presented by the shim itself.
export SDL3SHIM_SDL2_LIB="$GAMEDIR/lib/libSDL2-mmiyoo.so.0"
export SDL3SHIM_SDL2_VIDEODRIVER=evdev
# Render size. 640x480: lowering this to 480x360 changed neither the audio nor
# the frame rate, so the drawing is not what the game is short of. The engine's
# simulation step (POPLIB_FRAME_TIME, POPLIB_UPDATE_MULTIPLIER in the binary) was
# tried too and only made the game slower -- it caps the update rate instead of
# raising it, and the music is fed on demand by OpenAL, so it never followed it.
export SDL_DUMMY_MODE=640x480

# love-mmiyoo's patched driver polls this device for input; without it no key or
# pad event ever reaches SDL2 (and so none reaches the game).
export SDL_EVDEV_DEVICES="2:/dev/input/event0"
echo "--- input devices ---"
ls -l /dev/input/ 2>&1
for d in /sys/class/input/event*; do
  echo "$d name=$(cat $d/device/name 2>/dev/null)"
done

# The game links SDL3, and the shim's only video driver is named "sdl2".
export SDL_VIDEODRIVER=sdl2

# Pixels the pointer moves per d-pad step. It moves on every key repeat as well
# as every frame, so this is small on purpose.
export SDL3SHIM_MOUSE_STEP=6

# Software rendering, deliberately. The GL here (glsoft) is a fixed-pipeline
# rasterizer built around LÖVE's shaders: it takes the projection from a
# ClipSpaceFromLocal uniform and runs every other shader as a passthrough with
# an identity transform. SDL3's renderer shaders have no such uniform, so its
# output lands off-screen. The shim draws into a plain buffer instead and writes
# that buffer to the panel, with no shaders involved.
export SDL_RENDER_DRIVER=software

# The panel device the shim presents into.
export GLSOFT_FB=/dev/fb0

# Debug aid: the shim writes the first frames here.
export SDL3SHIM_DUMP_FRAME="$GAMEDIR/frame"

# Audio, through ALSA. The OSS path this port shipped with is a dead end on this
# device: /dev/dsp accepts the rate it is given and then clocks slower, so the
# sound came out dragged. ALSA is what the hardware actually uses, and the ALSA
# backend had to be compiled into OpenAL for it -- the build the port shipped has
# only oss/null/wave.
#
# Everything below this line sounded slow because of a leftover, not a setting:
# the frequency sweep used to diagnose the OSS path -- one rate per launch,
# rewriting this very config -- was still in place, and had landed on 16000 Hz.
# It overwrote whatever rate was set here on every launch, which is why every
# rate and every backend change sounded identical: none of them was the rate
# actually in use.
#
# The ALSA backend is now compiled into OpenAL and the config is left alone.
# This hardware takes 8000/16000/32000/48000 Hz -- there is no 44100, which is
# what this game's music is authored at -- so 48000 is asked for and OpenAL
# resamples to it.
export ALSOFT_DRIVERS=oss
export ALSOFT_CONF="$GAMEDIR/alsoft.conf"
# 3, not 2: at 2 only warnings are printed, so there is no way to see which
# backend was opened, at what rate, or which settings were read.
export ALSOFT_LOGLEVEL=3

# Attempt counter left behind by that sweep.
rm -f "$GAMEDIR/audio_try"

export POPLIB_FULLSCREEN=1
export POPLIB_SOFTWARE_CURSOR=1
export POPLIB_ONSCREEN_KEYBOARD=1

mkdir -p "$GAMEDIR/conf"
export XDG_CONFIG_HOME="$GAMEDIR/conf"

echo "--- env (relevant) ---"
env | grep -Ei '^(SDL|GLSOFT|ALSOFT|POPLIB|LD_|HOME|XDG|TERM)' | sort

echo "--- lib dir ---"
ls -l "$GAMEDIR/lib"

echo "--- running game ---"

# Clock management: use nominal 1200 MHz rather than 1500 MHz overclock to avoid excessive battery drain and thermal throttling.
SYSTEM_DIR=/mnt/SDCARD/.tmp_update
CPU_CLOCK="$SYSTEM_DIR/bin/cpuclock"
CPU_INITIAL=""
if [ -x "$CPU_CLOCK" ]; then
  CPU_INITIAL=$("$CPU_CLOCK" 2>/dev/null)
  if "$CPU_CLOCK" 1200 >/dev/null 2>&1; then
    echo "cpuclock: $CPU_INITIAL -> 1200 MHz"
  else
    echo "cpuclock: could not set clock"
    CPU_INITIAL=""
  fi
fi

# Keep audioserver running for /dev/dsp
echo "audioserver status: $(pidof audioserver 2>/dev/null || echo 'not running')"

(
  sleep 5
  echo "=== AUDIO HARDWARE PROBE ==="
  echo "--- /proc/asound/pcm ---"
  cat /proc/asound/pcm 2>&1
  echo "--- /proc/asound/card0/pcm0p/sub0/hw_params ---"
  cat /proc/asound/card0/pcm0p/sub0/hw_params 2>&1
  echo "--- /proc/asound/card0/pcm0p/sub0/status ---"
  cat /proc/asound/card0/pcm0p/sub0/status 2>&1
  echo "--- /proc/mi_modules/mi_ao/mi_ao0 ---"
  cat /proc/mi_modules/mi_ao/mi_ao0 2>&1
  echo "--- processes with audio / dsp open ---"
  lsof 2>/dev/null | grep -E 'pcm|dsp|snd|audio' || ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep -E 'pcm|dsp|snd|audio' || true
  echo "--- dmesg audio ---"
  dmesg | grep -i -E 'ao|audio|sound|pcm|rate|codec|i2s|ss_ao' | tail -n 25
  echo "=== END AUDIO PROBE ==="
) >> "$LOG" 2>&1 &

"$GAMEDIR/Insaniquarium"
RET=$?
echo "--- game exit code: $RET ---"

if [ -n "$CPU_INITIAL" ]; then
  "$CPU_CLOCK" "$CPU_INITIAL" >/dev/null 2>&1
  echo "cpuclock: restored to $CPU_INITIAL MHz"
fi

echo "=== done ==="
exit $RET
