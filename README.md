# Insaniquarium Deluxe — Miyoo Mini / Flip Native Port

[Leer en español](README.es.md)

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Miyoo%20Mini%20%2F%20Flip%20(OnionOS)-red.svg)]()

A native ARMv7 (`armhf`) port of **Insaniquarium Deluxe** running on the **Miyoo Mini Flip** (and likely compatible with the **Miyoo Mini / Miyoo Mini Plus**) under OnionOS.

This port is built upon the decompilation work by [WinFish](https://github.com/vindirect/winfish), the [PopLib](https://github.com/teampopwork/poplib) engine framework, and the PortMaster port created by [SaMeiers](https://github.com/SaMeiers/insaniquarium-port).

---

## Compatibility

- **Miyoo Mini Flip**: Fully tested and verified on physical hardware running **OnionOS v4.4.0-beta-20260120** (stable performance, audio in sync, normal thermals, minimal battery drain).
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

1. Extract the release `.zip` archive directly into the root of your SD card (it automatically places all required files into `Roms/PORTS/`).
2. Copy the original game asset folders (`data/`, `fishsongs/`, `images/`, `music/`, `properties/`, `sounds/`) into:
   ```text
   /mnt/SDCARD/Roms/PORTS/Games/Insaniquarium/
   ```
*(Then refresh ROMs in OnionOS and launch the game from the Ports section).*

---

## Controls

| Button | In-Game Action |
|---|---|
| **D-Pad / Analog Stick** | Move mouse pointer |
| **A** | Left Click |
| **B** | Right Click |
| **L1 / L2** | Speed up pointer |
| **R1 / R2** | Slow down pointer |
| **Start** | Pause game (Spacebar) |
| **Menu Button (Miyoo)** | Quit game |

---

## Development, AI Transparency & Technical Challenges

### Transparency Regarding AI

**I am not a professional low-level C++ or embedded systems developer.** This project was born out of the desire to play Insaniquarium Deluxe on my Miyoo Mini Flip, but achieving this exceeded my technical knowledge.

This port was made possible through active pair-programming with modern artificial intelligence models (**DeepSeek V4 Flash** and **Gemini 3.8 Flash**).

Every change was tested, measured, and debugged on a physical Miyoo Mini Flip using live telemetry and logs.

The models were used to analyze execution traces, frame cycle behavior, and kernel interfaces to pinpoint the exact root causes of bottlenecks.

The complete build environment, Dockerfiles, scripts, and patches are published openly so the community can inspect, audit, and improve the code.

### Key Problems Solved During Development

Porting the game to the Miyoo Mini's dual-core Cortex-A7 (SigmaStar SSD202D) revealed several unique challenges that had to be diagnosed and resolved:

1. **Audio Latency and Slow-Motion Resampling:**
   - *Problem*: Sound effects and music ran dragged in slow motion and with over 1 second of delay.
   - *Fix*: The Miyoo platform relies on a proprietary `/dev/dsp` audio driver managed by OnionOS's background `audioserver`. We configured OpenAL Soft (`alsoft.conf`) with the driver OSS forced to the hardware's native **48000 Hz** and kept `audioserver` active via `libpadsp.so` hooks.

2. **Freezes on Level Start or Enemy Spawns:**
   - *Problem*: Starting a level or spawning an enemy caused a 2-3 second complete freeze while background music sputtered.
   - *Fix*: The OpenMPT music streaming interface (`openmptmusicinterface.cpp`) was choking on large audio buffer queueing. We streamlined the streaming buffer to 4x4096 chunks and switched to lightweight linear interpolation, preventing thread starvation.

3. **FPS Drops and the SDL3 'Rotozoom' Bottleneck:**
   - *Problem*: As the tank filled with fish in later levels, the framerate plummeted whenever fish swam to the left.
   - *Fix*: Profiling revealed that SDL3's software renderer (`SDL_render_sw.c`) treats any mirrored blit (`SDL_FLIP_HORIZONTAL`) as an arbitrary rotation/stretch (`SW_RenderCopyEx`), executing floating-point trigonometric calculations and **two heap allocations per single blit**. With several fish on screen, memory fragmentation and CPU overhead caused severe hitching. We implemented a lazy horizontal texture mirror cache (`GetMirroredTexture`), converting flipped fish blits into direct 1:1 zero-allocation `SDL_RenderTexture` calls.

4. **Frame Pacing & Battery Optimization:**
   - *Problem*: Game logic was either sleeping for full 10ms OS kernel ticks (dropping frames) or running uncapped (draining 10% battery every 10 minutes with noticeable heat).
   - *Fix*: Adjusted frame loop pacing to sleep only when well ahead of the 16.6ms frame budget, disabled heavy full-screen presentation alpha blending, and set the CPU governor to nominal 1200 MHz instead of aggressive 1500 MHz overclocking.

---

## Building from Source

A reproducible compilation environment using Docker is provided.

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
   *(Or alternatively: `docker compose run --rm builder`)*

The compiled binary `Insaniquarium` will be output to the build directory ready for packaging.

---

## Credits & Acknowledgments

- **PopCap Games / Electronic Arts**: For creating *Insaniquarium Deluxe*.
- **[WinFish](https://github.com/vindirect/winfish) by vindirect**: For the decompilation work that forms the basis of the modern game logic.
- **[PopLib](https://github.com/teampopwork/poplib) by Team Popwork**: For the cross-platform modern engine rewrite replacing PopCap's SexyAppFramework.
- **[SaMeiers](https://github.com/SaMeiers/insaniquarium-port)**: For the initial PortMaster port, build system, and fixups that made this handheld port possible.
- **[bmdhacks](https://github.com/bmdhacks/SDL)**: For the SDL3-via-SDL2 shim backend.
- **OnionOS Team & Miyoo Community**: For the ongoing software ecosystem.

---

## License

This port is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**, inherited from `PopLib` and `insaniquarium-port`. See the [LICENSE](LICENSE) file for complete details.

Individual components and submodules retain their respective upstream licenses (SDL, libopenmpt, OpenAL Soft, zlib, miniaudio). All original game assets, art, sounds, and trademarks remain the sole property of PopCap Games / Electronic Arts.

