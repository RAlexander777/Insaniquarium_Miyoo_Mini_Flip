#!/bin/bash
# Build the SDL3-over-SDL2 shim for the Miyoo Mini (armv7 hf, glibc 2.28).
#
# This is not really SDL3: it is an SDL3 API that forwards to whatever SDL2 the
# firmware has, which is what PortMaster expects a port to use. It reaches SDL2
# with dlopen("libSDL2-2.0.so.0") at runtime (src/video/sdl2/SDL_sdl2video.c),
# so nothing of SDL2 is needed to build it -- only the device's SDL2 must be
# next to the game at runtime.
#
# Runs inside the miyoo-builder image. Source and build tree live in the
# miyoo-shim volume; /host is the Windows working directory.
set -euo pipefail

mkdir -p /work
exec > >(tee /work/shim.log) 2>&1

export PATH=/opt/cmake/bin:$PATH
SYS=/opt/miyoomini-toolchain/arm-linux-gnueabihf/libc
WORK=/work/shim
TOOLCHAIN=/host/insaniquarium-port/port/toolchain-armhf-miyoo.cmake
PORT=/host/insaniquarium-port/port

if [ ! -d "$WORK/SDL/include" ]; then
  echo "== seeding source into the volume"
  mkdir -p "$WORK"
  cp -a /host/shim-src "$WORK/SDL"
  cp -a /host/SPIRV-Cross "$WORK/SPIRV-Cross"
fi

# This port patches the shim's sdl2 backend (the framebuffer used to be a stub).
# It is re-synced AFTER the git checkout below, or that checkout would revert it.

# Reset first, so a rebuild does not depend on what the last one left behind.
echo "== patches"
git -C "$WORK/SDL" checkout -q -- . 2>/dev/null || true
for aPatch in "$PORT"/patches/shim/*.patch; do
  [ -e "$aPatch" ] || continue
  tr -d '\r' < "$aPatch" | git -C "$WORK/SDL" apply - || echo "   WARNING: $(basename "$aPatch") did not apply"
  echo "   $(basename "$aPatch")"
done

# Now the port's own changes to the backend. The rest of the SDL tree keeps its
# object files; only this directory is rebuilt.
echo "== re-syncing the sdl2 backend"
rm -rf "$WORK/SDL/src/video/sdl2"
cp -a /host/shim-src/src/video/sdl2 "$WORK/SDL/src/video/"

# The shim's C++ glue pulls in the toolchain's static libstdc++, which is built
# against a much newer glibc than the sysroot has.
echo "== glibc compatibility object"
INCLUDES=$(arm-linux-gnueabihf-g++ -E -Wp,-v -xc++ /dev/null 2>&1 \
           | grep '^ /usr' | grep -E 'c\+\+|gcc-cross' | sed 's|^ |-isystem |' | tr '\n' ' ')
# shellcheck disable=SC2086
arm-linux-gnueabihf-g++ -c -fPIC -O2 --sysroot="$SYS" -nostdinc $INCLUDES \
  -isystem "$SYS/usr/include" \
  -o "$WORK/compat-glibc.o" "$PORT/compat-glibc.cpp"
arm-linux-gnueabihf-ar rcs "$WORK/libcompat.a" "$WORK/compat-glibc.o"

echo "== configure"
rm -rf "$WORK/SDL/build"
cmake -S "$WORK/SDL" -B "$WORK/SDL/build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DWINFISH_SYSROOT="$SYS" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_STANDARD_LIBRARIES="$WORK/libcompat.a" \
  -DSDL_SDL2_BACKEND=ON \
  -DSDL_SPIRV_CROSS_DIR="$WORK/SPIRV-Cross" \
  -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_KMSDRM=OFF \
  -DSDL_PIPEWIRE=OFF -DSDL_PULSEAUDIO=OFF -DSDL_ALSA=OFF \
  -DSDL_SNDIO=OFF -DSDL_OSS=OFF -DSDL_JACK=OFF \
  -DSDL_OFFSCREEN=OFF -DSDL_DUMMYVIDEO=OFF \
  -DSDL_DUMMYAUDIO=OFF -DSDL_DISKAUDIO=OFF \
  -DSDL_VULKAN=OFF -DSDL_GPU=ON -DSDL_RENDER_GPU=ON \
  -DSDL_UNIX_CONSOLE_BUILD=ON -DSDL_TESTS=OFF

echo "== build"
cmake --build "$WORK/SDL/build" --parallel "$(nproc)"

LIB=$(ls "$WORK/SDL/build"/libSDL3.so.0.* 2>/dev/null | head -1)
[ -f "$LIB" ] || { echo "no library produced"; exit 1; }

echo
echo "=== result ==="
file "$LIB"
echo "--- highest glibc version required ---"
arm-linux-gnueabihf-objdump -T "$LIB" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -4
echo "--- soname / needed ---"
arm-linux-gnueabihf-readelf -d "$LIB" | grep -E 'SONAME|NEEDED'

mkdir -p /host/out
arm-linux-gnueabihf-strip -o /host/out/libSDL3.so.0 "$LIB"
echo "copied to /host/out/libSDL3.so.0"
