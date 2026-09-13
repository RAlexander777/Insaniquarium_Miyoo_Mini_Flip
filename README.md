# Insaniquarium Deluxe — Miyoo Mini / Flip Native Port

[Leer en español](README.es.md)

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Miyoo%20Mini%20%2F%20Flip%20(OnionOS)-red.svg)]()

A native ARMv7 (`armhf`) port of **Insaniquarium Deluxe** running on the **Miyoo Mini Flip** (and likely compatible with the **Miyoo Mini / Miyoo Mini Plus**) under OnionOS.

This port is built upon the decompilation work by [WinFish](https://github.com/vindirect/winfish), the [PopLib](https://github.com/teampopwork/poplib) engine framework, and the PortMaster port created by [SaMeiers](https://github.com/SaMeiers/insaniquarium-port).

---

## Compatibility

- **Miyoo Mini Flip**: Fully tested and verified on physical hardware (stable performance, audio in sync, normal thermals, minimal battery drain).
- **Miyoo Mini / Miyoo Mini Plus**: Built against the standard Miyoo Mini toolchain (`glibc 2.28`, ARMv7 Cortex-A7). While untried by the author due to lacking the hardware, it shares the same SoC/OS architecture and is expected to work. Feedback and PRs are welcome!

---

## Important Legal Notice: Game Assets Not Included

**This repository contains NO proprietary game assets.** You must supply the game data files from your own legally purchased copy of **Insaniquarium Deluxe** (Steam, PopCap CD-ROM, etc.).

### Required Game Files

From your PC game installation, copy the following folders:

```text
data/
fishsongs/
images/
music/
properties/
sounds/
```

> [!WARNING]
> **Linux Case Sensitivity:**
> Unlike Windows, Linux filesystems are case-sensitive. If the game halts complaining about a missing image or file that you know is present, check the filename capitalization and ensure it matches what the game requests.

---

## Installation on Miyoo Mini / Flip

1. Ensure your Miyoo device is running **OnionOS**.
2. Place `Insaniquarium.port` into your SD card under:
   ```text
   /mnt/SDCARD/Roms/PORTS/
   ```
3. Place the port directory contents (`Insaniquarium` binary, `script.sh`, `alsoft.conf`, `lib/`, etc.) into:
   ```text
   /mnt/SDCARD/Roms/PORTS/Games/Insaniquarium/
   ```
4. Copy the required asset folders listed above (`data/`, `images/`, `music/`, `properties/`, `sounds/`, `fishsongs/`) directly into:
   ```text
   /mnt/SDCARD/Roms/PORTS/Games/Insaniquarium/
   ```
5. Refresh your ROM list in OnionOS, navigate to the **Ports** section, and launch **Insaniquarium**.

---

## Controls

Because Insaniquarium was originally designed for PC mouse gameplay, the handheld buttons map to a virtual cursor and mouse buttons:

| Button | In-Game Action |
|---|---|
| **D-Pad / Analog Stick** | Move virtual mouse pointer |
| **A** | Left Click (feed fish, collect coins, attack aliens, confirm) |
| **B** | Right Click (activate pet special ability, cancel / drop) |
| **X** | Secondary action / Cancel |
| **Y** | Auto-Collect All Coins (sweeps all coins on screen when enabled in Options) |
| **L1 / R1** | Precision Slow Movement (slows pointer down for fine accuracy) |
| **Start** | Enter / Pause / In-game Menu |
| **Select** | Escape / Back |
| **Menu Button (Miyoo)** | OnionOS Game Switcher / System Menu |

> [!TIP]
> **Auto-Collect Coins:** In the game's Options menu, you can toggle *Auto Collect*. When enabled, pressing **Y** instantly gathers every coin floating in your tank without needing to hover and click each one individually.

---

## The Story: Development, AI Transparency & Technical Challenges

### Complete Transparency Regarding AI

I want to be 100% transparent with the community: **I am not a professional low-level C++ embedded developer.** Prior to this project, cross-compiling legacy engines, patching toolchains, and debugging Linux audio hardware was well outside my skill set.

This port was achieved by actively pair-programming with modern AI reasoning models (**DeepSeek V4 Flash** and **Gemini 3.8 Flash**).

In an open-source landscape increasingly wary of unverified "AI slop" or speculative code dumps, this project stands on different principles:
- **Zero Hallucination Tolerance**: Every change was tested, validated, and profiled on physical Miyoo hardware via live telemetry and logs.
- **Root-Cause Engineering**: Rather than blind trials, the models were used to analyze disassembled traces, frame pacing behavior, and kernel interfaces to locate the exact source of bottlenecks.
- **Reproducible & Inspectable**: All build configurations, Dockerfiles, and patches are fully published in this repository for the community to audit, modify, and improve.

### Key Problems Solved on Hardware

Porting the game to the Miyoo Mini's dual-core Cortex-A7 (SigmaStar SSD202D) revealed several unique challenges that had to be diagnosed and resolved:

1. **Audio Latency and Slow-Motion Resampling:**
   - *Problem*: Sound effects and music ran dragged in slow motion with over 1 second of delay.
   - *Fix*: The Miyoo platform relies on a proprietary `/dev/dsp` audio driver managed by OnionOS's background `audioserver`. We configured OpenAL Soft (`alsoft.conf`) with `drivers = oss`, forced the output sampling rate to the hardware's native **48000 Hz**, and kept `audioserver` active via `libpadsp.so` hooks.

2. **Alien Spawn Freezes & Music Starvation:**
   - *Problem*: Starting a level or spawning an alien caused a 2-3 second complete freeze while background music sputtered.
   - *Fix*: The OpenMPT music streaming interface (`openmptmusicinterface.cpp`) was choking on large audio buffer queueing. We streamlined the streaming buffer to 4x4096 chunks and switched to lightweight linear interpolation, preventing thread starvation.

3. **Level 3+ Frame Drops & The SDL3 Software "Rotozoom" Bottleneck:**
   - *Problem*: As the tank filled with fish in later levels, the framerate plummeted whenever fish swam to the left.
   - *Fix*: Profiling revealed that SDL3's software renderer (`SDL_render_sw.c`) treats any mirrored blit (`SDL_FLIP_HORIZONTAL`) as an arbitrary rotation/stretch (`SW_RenderCopyEx`), executing floating-point trigonometric calculations and **two heap allocations per single blit**. With dozens of swimming fish, memory fragmentation and CPU overhead caused severe hitching. We implemented a lazy horizontal texture mirror cache (`GetMirroredTexture`), converting flipped fish blits into direct 1:1 zero-allocation `SDL_RenderTexture` calls.

4. **Frame Pacing & Battery Optimization:**
   - *Problem*: Game logic was either sleeping for full 10ms OS kernel ticks (dropping frames) or running uncapped (draining 10% battery every 10 minutes with noticeable heat).
   - *Fix*: Adjusted frame loop pacing to sleep only when well ahead of the 16.6ms frame budget, disabled heavy full-screen presentation alpha blending, and set the CPU governor to nominal 1200 MHz instead of aggressive 1500 MHz overclocking.

---

## Building from Source

A containerized cross-compilation environment using Docker is provided.

### Prerequisites

- Docker or Docker Desktop
- The Miyoo Mini toolchain archive (`miyoomini-toolchain.tar.xz`)

### Build Steps

1. Clone this repository with submodules:
   ```bash
   git clone --recurse-submodules https://github.com/RAlexander777/Insaniquarium_Miyoo_Mini_Flip.git
   cd Insaniquarium_Miyoo_Mini_Flip
   ```

2. Build the Docker builder image:
   ```bash
   docker build -t miyoo-insaniquarium-builder -f docker/Dockerfile.miyoo .
   ```

3. Run the build script inside the container:
   ```bash
   docker run --rm -v $(pwd):/host -w /host miyoo-insaniquarium-builder ./build-armhf.sh
   ```

The compiled binary `Insaniquarium` will be output to the build directory ready for packaging.

---

## Credits & Acknowledgments

- **PopCap Games / Electronic Arts**: For creating *Insaniquarium Deluxe*, an timeless childhood classic.
- **[WinFish](https://github.com/vindirect/winfish) by vindirect**: For the incredible decompilation effort that forms the basis of the modern game logic.
- **[PopLib](https://github.com/teampopwork/poplib) by Team Popwork**: For the cross-platform modern engine rewrite replacing PopCap's SexyAppFramework.
- **[SaMeiers](https://github.com/SaMeiers/insaniquarium-port)**: For the fantastic PortMaster port, build system, and fixups that made this handheld port possible.
- **[bmdhacks](https://github.com/bmdhacks/SDL)**: For the SDL3-via-SDL2 shim backend.
- **OnionOS Team & Miyoo Community**: For the ongoing software ecosystem and toolchains.

---

## License

This port is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**, inherited from `PopLib` and `insaniquarium-port`. See the [LICENSE](LICENSE) file for complete details.

Individual components and submodules retain their respective upstream licenses (SDL, libopenmpt, OpenAL Soft, zlib, miniaudio). All original game assets, art, sounds, and trademarks remain the sole property of PopCap Games / Electronic Arts.
