# Insaniquarium Deluxe — Miyoo Mini / Flip Native Port

[Leer en español](README.es.md)

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Miyoo%20Mini%20%2F%20Flip%20(OnionOS)-red.svg)]()

A native port of **Insaniquarium Deluxe** running on the **Miyoo Mini Flip** (and likely compatible with the **Miyoo Mini / Miyoo Mini Plus**) under [OnionOS](https://github.com/onionui/Onion).

This port is built upon the decompilation work by [WinFish](https://github.com/vindirect/winfish), the [PopLib](https://github.com/teampopwork/poplib) engine framework, and the PortMaster port created by [SaMeiers](https://github.com/SaMeiers/insaniquarium-port).

---

## Compatibility

- **Miyoo Mini Flip**: Fully tested and verified on physical hardware running **OnionOS v4.4.0-beta-20260120** (smooth and stable performance, synchronized audio, normal thermals, and moderate battery consumption).
- **Miyoo Mini / Miyoo Mini Plus**: Built against the standard Miyoo Mini toolchain (`glibc 2.28`, ARMv7 Cortex-A7). Although not directly tested, it shares the same SoC/OS architecture and should also work.

---

## Game Assets Not Included

**This repository contains NO proprietary game assets.** You must supply the game data files from a legitimate copy of **Insaniquarium Deluxe** (Steam version, original PopCap CD-ROM, etc.).

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
> **Case Sensitivity on Linux:**
> Unlike Windows, the Linux filesystem distinguishes between uppercase and lowercase letters (*case-sensitive*). If the game reports a missing image or asset that you know is present, check the filename and make sure it matches the exact capitalization requested by the game.

---

## Installation on Miyoo Mini / Flip

1. Extract the release `.zip` archive directly into your `Roms/PORTS/` directory on your SD card (it will place `Insaniquarium.port` and the `Games/Insaniquarium/` folder).
2. Copy the original game asset folders (`data/`, `fishsongs/`, `images/`, `music/`, `properties/`, `sounds/`) into:
   ```text
   /mnt/SDCARD/Roms/PORTS/Games/Insaniquarium/
   ```
*(Then in OnionOS, refresh the list with Refresh Roms and go to the Ports section to play).*

---

## Controls

| Button | In-Game Action |
|---|---|
| **D-Pad / Analog Stick** | Move mouse |
| **A** | Left click |
| **B** | Right click |
| **X** | Auto-collect all coins |
| **L1 / L2** | Speed up pointer |
| **R1 / R2** | Slow down pointer |
| **Start** | Pause game (Spacebar) |
| **Menu Button (Miyoo)** | Quit game |

---

## Development, AI Transparency & Technical Challenges

### Transparency Regarding AI

**I am not a professional low-level C++ or embedded systems developer.** This project came about from the desire to play Insaniquarium Deluxe on my Miyoo Mini Flip, but that task exceeded my technical knowledge.

This port was made possible through active pair-programming with modern artificial intelligence models (**DeepSeek V4 Flash** and **Gemini 3.8 Flash**).

Every change was tested, measured, and debugged on a Miyoo Mini Flip using live telemetry and logs.

The models were used to analyze execution traces, frame cycle behavior, and kernel interfaces to locate the exact root causes of bottlenecks.

The complete build environment, Dockerfiles, scripts, and patches are published openly so the community can inspect, audit, and improve the code.

### Problems Solved During Development

Porting the game to the Miyoo Mini's dual-core Cortex-A7 (SigmaStar SSD202D) architecture presented specific challenges that required technical diagnosis and solutions:

1. **Audio Latency and Slowdown (OSS Sampling):**
   
   - *Problem*: Sound effects and music sounded slowed down and with over a second of delay.
   - *Solution*: The Miyoo uses a `/dev/dsp` driver managed by OnionOS's `audioserver`. OpenAL Soft (`alsoft.conf`) was configured with the OSS driver forced to the native **48000 Hz** sample rate and `audioserver` was kept active by preloading `libpadsp.so`.

2. **Freezes on Level Start or Enemy Spawns:**
   
   - *Problem*: Starting a level or spawning an enemy caused a 2-3 second freeze while the music stuttered.
   - *Solution*: The OpenMPT music streaming interface (`openmptmusicinterface.cpp`) became saturated due to excessive buffer sizes. Queuing was optimized to 4x4096 sample chunks and interpolation was switched to lightweight linear, eliminating thread starvation.

3. **FPS Drops and the SDL3 "Rotozoom" Bottleneck:**
   
   - *Problem*: As the tank filled with fish starting from level 3, the framerate dropped drastically whenever a fish swam to the left.
   - *Solution*: Profiling revealed that SDL3's software renderer (`SDL_render_sw.c`) handles horizontally flipped blits (`SDL_FLIP_HORIZONTAL`) by invoking a complex rotation and scaling routine (`SW_RenderCopyEx`), which executes trigonometric operations and **two dynamic heap allocations per fish frame**. With several fish on screen, memory fragmentation and CPU overhead collapsed performance. A lazy mirrored texture cache (`GetMirroredTexture`) was implemented, converting flipped rendering into direct 1:1 blits (`SDL_RenderTexture`) with zero runtime allocations.

4. **Frame Pacing and Battery Consumption:**
   
   - *Problem*: The main game loop either slept for rigid 10ms intervals (causing stuttering) or ran uncapped (draining 10% battery every 10 minutes with a noticeable temperature rise).
   - *Solution*: Frame timing was adjusted to yield time only when the margin over 16.6ms is sufficient, costly full-screen alpha blending on presentation was eliminated, and the CPU clock was set to a nominal 1200 MHz instead of the 1500 MHz overclock.

---

## Building from Source

A reproducible compilation environment using Docker is provided.

### Prerequisites

- Docker or Docker Desktop
- Miyoo Mini toolchain archive (`miyoomini-toolchain.tar.xz`)

### Build Steps

1. Clone this repository including submodules:
   
   ```bash
   git clone --recurse-submodules https://github.com/RAlexander777/Insaniquarium_Miyoo_Mini_Flip.git
   cd Insaniquarium_Miyoo_Mini_Flip
   ```

2. Build the compiler image in Docker:
   
   ```bash
   docker build -t miyoo-insaniquarium-builder -f docker/Dockerfile.miyoo .
   ```

3. Run the compilation inside the container:
   
   ```bash
   docker run --rm -v $(pwd):/host -w /host miyoo-insaniquarium-builder ./build-armhf.sh
   ```
   
   *(Or alternatively: `docker compose run --rm builder`)*

The compiled binary `Insaniquarium` will be generated ready to package and transfer to the device.

---

## Credits & Acknowledgments

- **PopCap Games / Electronic Arts**: For creating *Insaniquarium Deluxe*.
- **[WinFish](https://github.com/vindirect/winfish) by vindirect**: For the decompilation work that makes the modern game logic possible.
- **[PopLib](https://github.com/teampopwork/poplib) by Team Popwork**: For the modern cross-platform engine that replaces SexyAppFramework.
- **[SaMeiers](https://github.com/SaMeiers/insaniquarium-port)**: For the initial PortMaster port and fixup scripts that served as the direct base for this version.
- **[bmdhacks](https://github.com/bmdhacks/SDL)**: For the SDL3-over-SDL2 compatibility layer (shim).
- **[OnionOS Team & Miyoo Community](https://github.com/onionui/Onion)**: For the continuous development of the ecosystem.

---

## License

This port is distributed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**, inherited from `PopLib` and `insaniquarium-port`. See the [LICENSE](LICENSE) file for the full text.

Individual components and submodules retain their respective original licenses (SDL, libopenmpt, OpenAL Soft, zlib, miniaudio). All original game assets, graphics, sounds, and trademarks are the exclusive property of PopCap Games / Electronic Arts.
