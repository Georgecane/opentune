# 🎵 OpenTune

![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![Engine](https://img.shields.io/badge/audio%20engine-C%2B%2B20-orange.svg)
![Status](https://img.shields.io/badge/status-pre--alpha-red.svg)

**OpenTune** is a free, open‑source, cross‑platform Digital Audio Workstation (DAW) built around a **C++20 audio engine** with a **stable C ABI**. The project targets Windows, macOS and Linux and is designed to be extensible, performant, and fully open‑source.

---

## 📦 Programming Stack

| Component | Language / Technology | Role |
|-----------|----------------------|------|
| Audio Engine | **C++20** | Real‑time, low‑latency audio processing. |
| Build System | **CMake 3.20+** | Compiles the native engine library. |
| C ABI Layer | **C-compatible header** (`opentune_engine.h`) | Stable interface for future UI bindings (C#, Rust, Python, etc.). |

The engine exposes a stable C ABI (`engine/include/opentune_engine.h`), allowing future UI front‑ends (Avalonia/.NET, Qt, web, etc.) to invoke engine functions safely without compromising real‑time performance.

---

## 🛠️ Build & Run

### Prerequisites

* **CMake 3.20+** – for the engine build.
* **C++20 compatible compiler** (MSVC 19.30+, GCC 11+, Clang 13+).
* **Git** – to clone the repository.

### Steps

```bash
# Clone the repository
git clone https://github.com/yourorg/opentune.git
cd opentune

# Build the native engine
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

The built shared library (`opentune_engine.dll` / `libopentune_engine.so` / `libopentune_engine.dylib`) will be in `build/bin/`.

### Running Tests

```bash
# From build directory
ctest --output-on-failure
```

---

## ⚠️ Project Status

OpenTune is currently **pre‑alpha**. The core audio engine is implemented in C++20 with a stable C ABI. The UI layer has not been implemented yet — the project is focused on building a solid, testable audio engine foundation first. Contributions are welcome, but the software is not yet suitable for production use.

---

## 📚 Documentation

* **Engine API** – generated header `engine/include/opentune_engine.h`.
* **Contribution Guide** – see `CONTRIBUTING.md` (to be added).

---

## 🤝 Contributing

We follow a **transparent, open** development model:

* Fork the repository and submit pull requests.
* Keep changes focused on a single concern (engine, UI, or tooling).
* Ensure tests pass (`ctest` from the build directory).
* Adhere to the coding standards outlined in `CODE_OF_CONDUCT.md`.

---

## 📜 License

OpenTune is licensed under the **GPLv3**. See `LICENSE` for the full text.

The project is built around one central idea:

> **A small and reliable core, an unlimited studio.**

## ✨ What Is OpenTune?

OpenTune is designed to become a serious open alternative to traditional commercial DAWs.

The goal is not to copy a specific application. Instead, OpenTune aims to combine the best ideas from modern music production tools while maintaining:

- A transparent and auditable codebase
- A predictable real-time audio engine
- A modern visual workflow
- A modular and extensible architecture
- A completely free and open-source core
- Cross-platform support for Windows, macOS and Linux

OpenTune is inspired by the workflows found in applications such as:

- Logic Pro
- Ableton Live
- Bitwig Studio
- REAPER
- Ardour

OpenTune is an independent project and is not affiliated with any of these products or their creators.

---

## 🧠 Core Principles

### 1. Real-Time Reliability

Audio processing must remain stable under pressure.

The audio thread should avoid:

- Memory allocation
- Blocking locks
- File-system operations
- Network operations
- UI calls
- Garbage collection
- Unbounded queues
- Unpredictable background work

The engine is designed around preallocated buffers, bounded communication, explicit ownership and predictable processing deadlines.

### 2. Open by Default

OpenTune is intended to remain free and open-source.

The project will prioritize:

- Open file formats
- Documented APIs
- Open plugin standards
- Reproducible builds
- Community contribution
- Transparent development

### 3. Modular Architecture

The audio engine, user interface, project system and content ecosystem should remain decoupled.

This allows each subsystem to evolve independently without turning the entire application into one tightly coupled codebase.

### 4. User Ownership

Users should own their projects, recordings, presets and content.

OpenTune should not require:

- A subscription
- An online account
- Cloud activation
- Internet access for basic functionality
- A proprietary project server

---

## 🚀 Why C++20?

The OpenTune audio engine is written in **C++20**.

C++20 is well-suited for the engine because it provides:

- Native performance
- Explicit memory management
- No garbage collector
- Predictable control over data structures
- RAII for resource management
- Excellent C interoperability (direct C ABI export)
- Cross-platform toolchain support (MSVC, GCC, Clang)
- Mature ecosystem of audio libraries
- Zero-cost abstractions where needed

C++20 features like concepts, `std::span`, `std::bit_cast`, and `constexpr` improvements allow writing safer, more expressive code without runtime overhead. The engine is compiled with exceptions and RTTI disabled on audio-critical paths to ensure predictable real-time behavior.

---

## 🖥️ C ABI as the Stable Interface

The OpenTune engine exposes a **stable C ABI** (`opentune_engine.h`) as its public interface.

Using a C ABI provides:

- Language-agnostic bindings — any language with C FFI (C#, Rust, Python, Zig, Go, etc.) can call the engine
- ABI stability across compiler versions
- No C++ name mangling or RTTI dependencies
- Clear API boundaries enforced by the header
- Opaque handles that hide implementation details
- Natural versioning via the API surface

No UI frontend has been built yet — the current focus is on the engine core. The C ABI ensures that when a UI layer is added, it can be implemented in any language without engine changes.

### Engine ↔ UI Boundary

The **C++ audio engine** and any future UI will communicate via the **stable C ABI**:

```
C++ Audio Engine
    │  Stable C ABI (opentune_engine.h)
    ▼
C FFI Bindings (any language)
    │  Commands & state snapshots
    ▼
Future UI (Avalonia / Qt / egui / etc.)
```

Key boundary traits:

* Opaque engine handles
* Fixed‑layout C‑compatible structs
* Numeric identifiers
* Explicit buffer ownership
* Versioned API functions
* Bounded command queues
* Read‑only state snapshots

The audio thread will never call into any UI runtime or allocate memory during real-time processing.

---

## 🏗️ Architecture Overview

OpenTune’s design is split into two current layers, with room for future expansion:

```
┌───────────────────────────┐
│   C ABI (opentune_engine.h) │  ←  Stable Public Interface
└─────────────▲─────────────┘
              │   Internal Calls
┌─────────────▼─────────────┐
│   C++ Audio Engine        │  ←  Real‑time DSP
└───────────────────────────┘
```

### 1. C++ Audio Engine
* C++20 code compiled as a shared library.
* Handles device I/O, audio graph execution, DSP, mixing, routing, MIDI, project management, and plugin processing.
* No heap allocations, locks, or OS calls on the audio thread.

### 2. C ABI Layer
* Exposes a **stable, versioned C ABI** (`opentune_engine.h`).
* Provides opaque handles, fixed‑layout structs, and command queues.
* Guarantees backward compatibility across engine revisions.

Future layers (UI, application logic) will sit above the C ABI and can be implemented in any language.

---

## 🎚️ Planned Features

### Audio

- Multi-track recording
- Non-destructive audio editing
- Waveform visualization
- Crossfades
- Clip gain
- Track and bus routing
- Sends and returns
- Sidechain routing
- Latency compensation
- Offline rendering
- Sample-accurate transport
- Multiple sample rates
- Multiple buffer sizes
- Input monitoring
- Punch recording
- Take management
- Comping

### MIDI

- MIDI input and output
- MIDI clips
- Piano roll
- MIDI editing
- Quantization
- Velocity editing
- Automation
- MPE support
- MIDI controller mapping
- Future MIDI 2.0 support

### Mixing

- Volume and pan
- Mute and solo
- Groups and buses
- Sends and returns
- Automation
- Metering
- Peak and RMS monitoring
- Plugin chains
- Track freezing
- Bounce and render workflows

### Project Management

- Versioned project format
- Autosave
- Undo and redo
- Non-destructive editing
- Portable project folders
- Media relinking
- Missing-file detection
- Project templates
- Consolidation and archiving

### User Interface

- Dockable panels
- Resizable workspace
- Keyboard-first workflows
- Custom themes
- High-DPI support
- Dark and light modes
- Localization
- Accessibility support
- Scalable timeline rendering

---

## 🔌 Plugin Strategy

OpenTune will prioritize open and well-documented plugin standards.

The initial plugin strategy is expected to focus on:

1. A native OpenTune processor API
2. CLAP support
3. LV2 support where appropriate
4. Additional formats after licensing and compatibility review

Third-party plugin processing should eventually support isolation or sandboxing so that an unstable plugin does not terminate the entire application.

Plugin hosting will be developed after the core audio graph and processing model are stable.

---

## 📦 Content Ecosystem

OpenTune will keep the application core separate from large sound libraries.

Users should be able to install optional content such as:

- Sample libraries
- Instrument libraries
- Presets
- Drum kits
- Templates
- Impulse responses
- Wavetables
- MIDI packs
- Community extensions

Content will be distributed separately from the core application and may use its own license.

OpenTune will not bundle copyrighted commercial content without permission.

---

## 🗂️ Repository Structure

```text
OpenTune/
├── engine/
│   ├── include/
│   │   └── opentune_engine.h          # Public C ABI header
│   └── src/
│       ├── audio/                     # Audio device I/O
│       ├── dsp/                       # DSP algorithms
│       ├── graph/                     # Audio graph
│       ├── mixer/                     # Mixer & channel strip
│       ├── midi/                      # MIDI handling
│       └── project/                   # Project & track management
│
├── tests/                             # Test sources
│
├── CMakeLists.txt                     # Top-level build
├── LICENSE
└── README.md
```

---

## 🛠️ Building from Source

### Requirements

- CMake 3.20+
- C++20 compatible compiler (MSVC 19.30+, GCC 11+, Clang 13+)
- Git
- Platform-specific audio development tools
- A supported desktop operating system

### Build the Engine

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

The built shared library will be in `build/bin/`.

### Run Tests

```bash
ctest --output-on-failure
```

---

## 🧪 Testing

OpenTune will use multiple levels of testing:

- Unit tests for DSP algorithms
- Deterministic offline rendering tests
- Audio graph tests
- Project format compatibility tests
- C ABI interop tests
- Fuzz testing for file parsers
- Performance benchmarks
- Real-time allocation checks
- Cross-platform CI builds

Every DSP algorithm should be testable without starting the graphical application.

---

## 🗺️ Roadmap

### Phase 0 — Foundation

- Define the C ABI
- Build the C++ engine library
- Open an audio device
- Produce and capture audio

### Phase 1 — Audio MVP

- Audio tracks
- Playback
- Recording
- Waveform display
- Basic editing
- Mixer
- Project save/load
- Undo/redo

### Phase 2 — Music Production

- MIDI clips
- Piano roll
- Automation
- Routing
- Buses
- Sends and returns
- Offline rendering

### Phase 3 — Extensibility

- Native OpenTune processors
- CLAP hosting
- Plugin scanning
- Plugin state management
- Presets
- Sandboxed processing

### Phase 4 — Professional Workflows

- Comping
- Track freezing
- Advanced editing
- Time stretching
- Pitch processing
- Multi-output instruments
- Hardware control
- Advanced project management

### Phase 5 — Ecosystem

- Optional sound libraries
- Community presets
- Extension APIs
- Documentation portal
- Localization community
- Portable content packages

---

## 🤝 Contributing

Contributions are welcome.

You can help with:

- C++ audio engine development
- DSP algorithms
- C ABI design
- MIDI support
- Testing
- Documentation
- Sound design
- User experience research

Before contributing large architectural changes, please open an issue or design discussion.

Please keep the following principles in mind:

- Do not block the real-time audio thread.
- Do not allocate memory in real-time processing paths.
- Do not expose C++ implementation details through the public ABI.
- Add tests for DSP and file-format changes.
- Keep UI and engine responsibilities separated.
- Document platform-specific behavior.

---

## 🔐 Security

If you find a security vulnerability, please do not immediately publish unpatched exploit details in a public issue.

See [SECURITY.md](SECURITY.md) for the responsible disclosure process.

---

## 📄 License

OpenTune is free and open-source software licensed under the **GNU General Public License v3.0**.

See [LICENSE](LICENSE) for the complete license text.

Third-party dependencies, libraries, plugins, fonts, samples and content may be distributed under their own licenses. Always review the license of external content before redistributing it.

---

## 🌍 Vision

OpenTune is more than an audio editor.

It is an attempt to build a transparent, extensible and community-driven foundation for music production.

A DAW that respects its users.

A DAW that does not hide its architecture.

A DAW that can grow from a lightweight core into a complete studio.

> **OpenTune: a small core, an unlimited studio.**
