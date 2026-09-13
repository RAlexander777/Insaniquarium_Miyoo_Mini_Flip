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

# This port uses the SDL2 that Balatro uses on this device: love-mmiyoo's, which
# renders with software GL (glsoft) straight into /dev/fb0. libpadsp hooks fb0
# and the audio path, and that stack uses neither, so it is dropped -- it is
# love-mmiyoo's own rule.
unset LD_PRELOAD
echo "LD_PRELOAD=[${LD_PRELOAD:-}]"

export LD_LIBRARY_PATH="$GAMEDIR/lib:$LD_LIBRARY_PATH"

# This port renders with love-mmiyoo's SDL2 + glsoft. The libEGL/libGLESv2 that
# came with the other SDL2 build (SwiftShader) would be picked up by SDL2's
# fallback and render nowhere, so anything not used is moved aside. Onion's FTP
# does not support DELE, hence doing it here rather than deleting outside.
mkdir -p "$GAMEDIR/unused"
for f in libSDL2-2.0.so.0 libEGL.so libGLESv2.so libjson-c.so.5; do
  if [ -e "$GAMEDIR/lib/$f" ]; then
    mv "$GAMEDIR/lib/$f" "$GAMEDIR/unused/" 2>/dev/null
  fi
done

# The game links SDL3, and here that is the shim, whose only video driver is
# named "sdl2". "evdev" is not an SDL3 driver: it is the SDL2 driver name the
# shim passes down (love-mmiyoo's patched dummy driver polls input under it).
export SDL_VIDEODRIVER=sdl2
export SDL3SHIM_SDL2_VIDEODRIVER=evdev
export SDL3SHIM_SDL2_LIB="$GAMEDIR/lib/libSDL2-mmiyoo.so.0"

# glsoft: software OpenGL that presents into /dev/fb0. The panel on this device
# is 752x560 (the framebuffer reports 752x1680 at 32bpp: three 752x560 pages),
# not the 640x480 of the Mini, so the dummy desktop matches the panel.
export SDL_VIDEO_GL_DRIVER="$GAMEDIR/lib/libglsoft.so"
export SDL_DUMMY_MODE=752x560
export GLSOFT_FB=/dev/fb0
export GLSOFT_FILTER=nearest
export GLSOFT_KEEP_CONTEXT=1
# glsoft's own diagnostics: whether it loaded, which framebuffer it opened and
# what it drew.
export GLSOFT_LOG="$GAMEDIR/glsoft.log"

# Debug aid: the shim writes a few frames here, so a black panel can be told
# apart from a game that never draws anything.
export SDL3SHIM_DUMP_FRAME="$GAMEDIR/frame"

# OpenAL in this build has no ALSA backend (supported list: oss, null, wave).
# The OSS device is provided by libpadsp, which is not preloaded here, so this
# is expected to still fail; the game now survives it.
export ALSOFT_DRIVERS=oss
export ALSOFT_CONF="$GAMEDIR/alsoft.conf"
export ALSOFT_LOGLEVEL=3

export POPLIB_FULLSCREEN=1
export POPLIB_SOFTWARE_CURSOR=1
export POPLIB_ONSCREEN_KEYBOARD=1

mkdir -p "$GAMEDIR/conf"
export XDG_CONFIG_HOME="$GAMEDIR/conf"

echo "--- env (relevant) ---"
env | grep -Ei '^(SDL|GLSOFT|ALSOFT|POPLIB|LD_|HOME|XDG|TERM)' | sort

echo "--- lib dir ---"
ls -l "$GAMEDIR/lib"

echo "--- framebuffers ---"
ls -l /dev/fb* 2>&1
echo "proc/fb:"; cat /proc/fb 2>&1
for d in /sys/class/graphics/fb*; do
  echo "$d name=$(cat $d/name 2>/dev/null) virtual=$(cat $d/virtual_size 2>/dev/null) bpp=$(cat $d/bits_per_pixel 2>/dev/null) stride=$(cat $d/stride 2>/dev/null) pan=$(cat $d/pan 2>/dev/null) yoffset=$(cat $d/yoffset 2>/dev/null)"
done

# Reading /dev/fb0 with dd (read()) can come back zeroed whatever is on screen,
# so this uses a small mmap-based dumper instead. It prints the driver's real
# geometry and how many bytes are not zero.
"$GAMEDIR/fbdump" /dev/fb0 "$GAMEDIR/fb_before.raw"

echo "--- gptokeyb ---"
"$GAMEDIR/gptokeyb" "Insaniquarium" -c "$GAMEDIR/insaniquarium.ini" &
GPTO=$!
sleep 1

echo "--- running game ---"

# Diagnostic: copy the panel framebuffer out while the game runs, through mmap.
( sleep 40; "$GAMEDIR/fbdump" /dev/fb0 "$GAMEDIR/fb1.raw"; \
  sleep 30; "$GAMEDIR/fbdump" /dev/fb0 "$GAMEDIR/fb2.raw" ) &

"$GAMEDIR/Insaniquarium"
RET=$?
echo "--- game exit code: $RET ---"

kill "$GPTO" 2>/dev/null
echo "=== done ==="
exit $RET
