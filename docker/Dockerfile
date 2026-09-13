# Cross-compilation environment for the Miyoo Mini (armv7 hf, glibc 2.28).
#
# A modern cross-gcc supplies the C++20 compiler and libstdc++, while the
# Miyoo's own sysroot supplies headers and stub libraries pinned to glibc 2.28.
# The two are mixed the way the insaniquarium-port toolchain file does it:
# -nostdinc, then the compiler's C++ headers back explicitly, then the sysroot.
FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc-arm-linux-gnueabihf \
        g++-arm-linux-gnueabihf \
        binutils-arm-linux-gnueabihf \
        make \
        ninja-build \
        pkg-config \
        file \
        python3 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/miyoo
ENV MIYOO_SYSROOT=/opt/miyoo/sysroot

WORKDIR /work
CMD ["/bin/bash"]
