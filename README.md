# 🎵 OpenTune

![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![Language](https://img.shields.io/badge/core%20language-Zig-f7a41d.svg)
![Status](https://img.shields.io/badge/status-pre--alpha-red.svg)

**OpenTune** is a free, open-source, cross-platform Digital Audio Workstation (DAW) designed to grow into a professional, industry-grade music production environment.

OpenTune is being built **Zig-first**, with the native audio engine and core systems implemented in Zig. The project is designed around real-time reliability, low latency, explicit resource management, portability, extensibility, and user ownership.

> **Professional audio. Open to everyone.**

---

## 🌍 Vision

OpenTune aims to become a complete, professional and globally accessible DAW without requiring proprietary software, subscriptions, activation servers, or closed project ecosystems.

The long-term vision includes:

- Professional multitrack recording
- Advanced audio editing
- Full MIDI production
- Software instruments
- Professional mixing and routing
- Automation and modulation
- Mastering workflows
- Low-latency real-time audio
- Open plugin standards
- Cross-platform native support
- Accessible and localized interfaces
- Portable and documented project formats
- A community-driven extension ecosystem

OpenTune is not intended to clone any particular commercial DAW. It is an independent project that aims to build a modern production environment from first principles.

---

## 🧠 Zig-First Architecture

**Zig is the primary programming language of OpenTune.**

The project is intentionally designed around Zig rather than using Zig merely as a wrapper around a C or C++ engine.

The long-term native core includes:

- Audio engine
- DSP
- Audio graph
- Mixer
- Routing
- MIDI engine
- Transport
- Recording
- Project system
- Automation
- Plugin hosting
- Offline rendering
- Platform abstraction
- Application infrastructure

Zig provides OpenTune with:

- Native performance
- Explicit memory allocation
- No garbage collector
- Compile-time safety checks
- Predictable data structures
- Low-level system access
- Cross-compilation
- C interoperability
- A simple native build system
- Fine-grained control over real-time resources

OpenTune will use Zig's capabilities while applying strict engineering practices for professional audio software.

### Important Safety Principle

Zig is not a fully memory-safe language.

Therefore, OpenTune will prioritize:

- Explicit ownership
- Clear lifetime rules
- Small unsafe sections
- Extensive testing
- Sanitizers during development
- Fuzz testing
- Deterministic offline rendering tests
- Real-time allocation checks
- Code review
- Defensive parsing of untrusted project and plugin data

Performance is important, but correctness and reliability come first.

---

## 🎚️ Real-Time Audio

The audio engine is the heart of OpenTune.

Real-time audio processing must meet strict deadlines. Audio-critical paths should therefore avoid unpredictable operations such as:

- Dynamic allocation during processing
- Blocking locks
- File-system operations
- Network operations
- UI calls
- Unbounded queues
- Unbounded computation
- Uncontrolled synchronization

The engine will favor:

- Preallocated resources
- Bounded communication
- Explicit ownership
- Lock-free or real-time-safe communication where appropriate
- Predictable processing graphs
- Sample-accurate timing
- Deterministic offline rendering

---

## 🏗️ Architecture

OpenTune is designed as a modular native application.

```
┌───────────────────────────────────────┐
│              OpenTune UI              │
├───────────────────────────────────────┤
│       Application / Project Layer     │
├───────────────────────────────────────┤
│       Timeline / MIDI / Automation   │
├───────────────────────────────────────┤
│        Audio Graph / Mixer / Bus     │
├───────────────────────────────────────┤
│             DSP / Engine              │
├───────────────────────────────────────┤
│       Audio I/O / Platform Layer      │
├───────────────────────────────────────┤
│                 Zig                   │
└───────────────────────────────────────┘
```

The exact implementation will evolve, but the architecture should keep these responsibilities independently testable.

### Core Subsystems

**Audio Engine**

Handles real-time processing, transport, buffers, device I/O, recording, playback and rendering.

**DSP**

Contains effects, filters, dynamics processors, synthesis, analysis and other signal-processing algorithms.

**Audio Graph**

Provides routing between tracks, buses, effects, instruments and outputs.

**MIDI**

Handles MIDI devices, events, clips, piano-roll data, controllers, MPE and future MIDI 2.0 integration.

**Project System**

Handles project serialization, media references, undo/redo, autosave, versioning and migration.

**Plugin System**

Hosts native OpenTune processors and external open plugin standards.

**UI**

Provides the professional workstation interface while remaining separated from the real-time audio thread.

---

## 🎛️ Planned Features

### Audio

- Multi-track recording
- Non-destructive editing
- Waveform visualization
- Clip gain
- Fades and crossfades
- Take management
- Comping
- Punch recording
- Time stretching
- Pitch processing
- Audio warping
- Sample-accurate transport
- Multiple sample rates
- Multiple buffer sizes
- Input monitoring
- Offline rendering
- Latency compensation

### MIDI

- MIDI input/output
- MIDI clips
- Piano roll
- MIDI editing
- Quantization
- Velocity editing
- Automation
- MPE
- MIDI controller mapping
- MIDI 2.0 support

### Mixing

- Volume and pan
- Mute and solo
- Groups and buses
- Sends and returns
- Sidechain routing
- Automation
- Peak/RMS metering
- Plugin chains
- Track freezing
- Bounce and rendering
- Multi-output routing

### Instruments & Sound Design

- Native synthesizers
- Samplers
- Drum machines
- Wavetable synthesis
- Granular processing
- Physical-modeling experiments
- Native instruments
- Community instruments
- Preset systems

### Project Management

- Versioned project format
- Autosave
- Undo/redo
- Portable projects
- Media relinking
- Missing-file detection
- Templates
- Consolidation
- Archiving
- Project migration

### User Interface

- Dockable panels
- Resizable workspace
- Keyboard-first workflows
- High-DPI support
- Dark and light themes
- Localization
- Accessibility
- Scalable timeline rendering
- Custom editor views
- Hardware controller integration

---

## 🔌 Plugin Ecosystem

OpenTune will prioritize open and well-documented plugin standards.

The initial strategy includes:

1. **Native OpenTune plugins**
2. **CLAP**
3. **LV2**
4. Additional formats where technically and legally appropriate

The native plugin architecture will be designed around real-time safety and explicit resource ownership.

Third-party plugins should eventually support process isolation or sandboxing so that a faulty plugin does not necessarily terminate the entire DAW.

---

## 🌐 Cross-Platform

OpenTune targets:

- Linux
- Windows
- macOS

The core should remain as platform-independent as practical, with operating-system-specific functionality isolated behind explicit interfaces.

Zig's cross-compilation capabilities are an important part of the project's portability strategy.

---

## 📦 Open Project Format

OpenTune should not lock users into a proprietary ecosystem.

The project format is intended to be:

- Documented
- Versioned
- Portable
- Extensible
- Recoverable
- Backward-aware
- Friendly to source control where practical

Projects should support:

- Autosave
- Undo/redo
- Media management
- Missing-file detection
- Relinking
- Consolidation
- Archiving
- Version migration

Users should retain control over their recordings, projects, presets and other creative work.

---

## 🗂️ Repository Structure

The repository will evolve with the architecture.

The intended direction is:

```text
OpenTune/
├── src/
│   ├── audio/
│   ├── dsp/
│   ├── graph/
│   ├── mixer/
│   ├── midi/
│   ├── project/
│   ├── plugins/
│   ├── platform/
│   └── ui/
│
├── tests/
│   ├── audio/
│   ├── dsp/
│   ├── graph/
│   ├── midi/
│   └── project/
│
├── docs/
├── examples/
├── build.zig
├── build.zig.zon
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── LICENSE
└── README.md
```

This structure is a direction rather than a rigid requirement. The architecture should evolve with the needs of the project.

---

## 🛠️ Building from Source

### Requirements

- Zig
- Git
- Platform-specific audio development tools
- A supported desktop operating system

### Build

```bash
zig build
```

### Run

```bash
zig build run
```

### Test

```bash
zig build test
```

Build and packaging workflows are expected to evolve throughout the pre-alpha phase.

---

## 🧪 Testing

OpenTune will use multiple levels of testing:

- Unit tests
- DSP correctness tests
- Audio graph tests
- Deterministic offline rendering
- Project format compatibility tests
- Plugin compatibility tests
- Fuzz testing
- Performance benchmarks
- Real-time allocation checks
- Cross-platform CI
- Regression testing

DSP algorithms should be testable independently from the graphical application whenever possible.

---

## 🗺️ Roadmap

### Phase 0 — Zig Foundation

- Establish the Zig project structure
- Define core ownership conventions
- Establish platform abstraction
- Build the first executable
- Initialize audio devices
- Establish automated testing
- Define the initial audio buffer model

### Phase 1 — Audio MVP

- Audio input/output
- Playback
- Recording
- Transport
- Basic tracks
- Waveform rendering
- Basic editing
- Project save/load

### Phase 2 — DAW Core

- Audio graph
- Mixer
- Routing
- Buses
- Sends/returns
- Automation
- MIDI
- Piano roll
- Offline rendering

### Phase 3 — Professional Production

- Advanced editing
- Comping
- Time stretching
- Pitch processing
- Latency compensation
- Plugin chains
- Track freezing
- Advanced automation
- Hardware control

### Phase 4 — Plugin Ecosystem

- Native OpenTune plugin API
- CLAP hosting
- LV2 integration
- Plugin scanning
- Plugin state management
- Presets
- Fault isolation

### Phase 5 — Global Ecosystem

- Localization
- Accessibility
- Community extensions
- Instrument ecosystem
- Sound libraries
- Preset sharing
- Developer SDK
- Documentation platform
- Community tooling

---

## 🤝 Contributing

OpenTune is intended to be a community-driven project.

Contributions are welcome in:

- Zig development
- Audio engineering
- DSP
- MIDI
- Plugin development
- UI/UX
- Testing
- Documentation
- Localization
- Accessibility
- Sound design

### Development Principles

- Do not block the real-time audio thread.
- Avoid allocation in real-time processing paths.
- Keep ownership explicit.
- Keep platform-specific code isolated.
- Test DSP and serialization behavior.
- Keep public interfaces documented.
- Prefer simple architecture over unnecessary abstraction.
- Design for professional audio workflows from the beginning.

---

## 🔐 Security

If you discover a security vulnerability, please avoid publishing unpatched exploit details in a public issue.

See [SECURITY.md](SECURITY.md) for the responsible disclosure process.

---

## 📜 License

OpenTune is free and open-source software licensed under the **GNU General Public License v3.0**.

See [LICENSE](LICENSE) for the complete license text.

Third-party dependencies, plugins, fonts, samples and other external content may have separate licenses.

---

## 🌍 Global Open-Source Audio

OpenTune is intended to become a global open-source platform for digital music production.

The project is built around a simple principle:

**Professional music production should be accessible without proprietary lock-in.**

OpenTune should be:

- Free to obtain
- Open to inspect
- Open to modify
- Open to extend
- Portable across supported platforms
- Accessible to musicians around the world
- Friendly to independent developers

---

## ⭐ Philosophy

OpenTune is not simply another DAW.

It is an attempt to build an open foundation for professional digital music production.

A DAW where the architecture is visible.

A DAW where users own their projects.

A DAW where developers can build without asking permission.

A DAW that can grow from a small real-time audio engine into a complete professional studio.

> **OpenTune: professional audio, open to everyone.**

---

## 📌 Current Status

OpenTune is currently in **pre-alpha development**.

The architecture and implementation are expected to change substantially as the Zig-based foundation is built.

Early development is focused on establishing the Zig-native core, real-time audio architecture, DSP model, project system, plugin architecture and cross-platform foundation before expanding into the complete DAW experience.
