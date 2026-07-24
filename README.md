# 🎵 OpenTune

![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![Engine](https://img.shields.io/badge/audio%20engine-Zig-orange.svg)
![UI](https://img.shields.io/badge/UI-Avalonia%20%2B%20.NET-purple.svg)
![Status](https://img.shields.io/badge/status-pre--alpha-red.svg)

**OpenTune** is a free, open-source, cross-platform Digital Audio Workstation designed to grow into a professional music production environment.

OpenTune combines a high-performance native audio engine written in **Zig** with a modern desktop interface built using **C#/.NET and Avalonia UI**.

The project is built around one central idea:

> **A small and reliable core, an unlimited studio.**

---

## ⚠️ Project Status

OpenTune is currently in the early development stage.

The audio engine, project format, UI architecture and public APIs are subject to change. The project is not yet intended for production use.

The current priority is to build a stable foundation for:

- Real-time audio processing
- Low-latency recording and playback
- A modular audio graph
- Cross-platform hardware support
- A responsive and scalable user interface
- A long-term open plugin and content ecosystem

---

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

## 🚀 Why Zig?

The OpenTune audio engine is written in **Zig**.

Zig is well-suited for the engine because it provides:

- Native performance
- Explicit memory allocation
- No garbage collector in the audio engine
- Predictable control over data structures
- Clear error handling
- Excellent C interoperability
- Cross-compilation support
- A simple and transparent build system

Zig also allows OpenTune to integrate with existing native audio libraries, operating-system APIs and plugin standards without requiring the entire project to be written in C or C++.

### Important Design Note

Zig gives developers control and useful compile-time checks, but it is not a fully memory-safe language.

OpenTune will therefore use strict engineering practices:

- Small unsafe sections
- Clear ownership rules
- Extensive testing
- Sanitizers in development
- Fuzz testing for parsers
- Offline audio rendering tests
- Real-time allocation checks
- Code review for engine changes

Performance is important, but correctness and reliability come first.

---

## 🖥️ Why Avalonia and .NET?

The OpenTune user interface is built with **Avalonia UI and C#/.NET**.

Avalonia provides:

- Cross-platform desktop UI
- Windows, macOS and Linux support
- Modern data binding
- Flexible layout and styling
- Native desktop windowing
- Accessibility support
- A productive development workflow
- A mature .NET ecosystem

Using .NET for the UI allows the project to move quickly when implementing:

- Project management
- Settings
- Menus and commands
- Keyboard shortcuts
- Localization
- Accessibility
- Plugin browsers
- Content management
- User preferences
- Background file operations

Avalonia is responsible for the application interface. It is not responsible for real-time audio processing.

### UI and Engine Boundary

The Zig engine and the .NET application communicate through a small, explicit C-compatible ABI.

```text
Zig Audio Engine
       │
       │  Stable C ABI
       │
C# Interop Layer
       │
       │  Commands and state snapshots
       │
Avalonia User Interface
```

The boundary will use:

- Opaque engine handles
- Fixed-layout C-compatible structs
- Numeric identifiers
- Explicit buffer ownership
- Versioned API functions
- Bounded command queues
- Read-only state snapshots

The audio thread will never call into the .NET runtime or Avalonia UI.

---

## 🏗️ Architecture

OpenTune is divided into several major subsystems.

### Zig Audio Engine

Responsible for:

- Audio device input and output
- Real-time processing
- Audio graph execution
- Track and bus processing
- Mixing
- Routing
- DSP
- Transport timing
- Recording
- Offline rendering
- Latency management
- Plugin processing

### C ABI Layer

Responsible for:

- Exposing stable engine functions
- Managing opaque handles
- Defining compatible data structures
- Providing versioned interop functions
- Isolating Zig implementation details from C#

The shared ABI header will be maintained as a first-class part of the project.

### C# Application Layer

Responsible for:

- Application state
- Commands and undo/redo
- Project loading and saving
- Settings
- File dialogs
- Background tasks
- Plugin metadata
- Content management
- Interop with the Zig engine

### Avalonia UI

Responsible for:

- Timeline
- Mixer
- Track controls
- Piano roll
- Transport controls
- Browser panels
- Plugin windows
- Project settings
- Themes
- Keyboard shortcuts
- Accessibility
- Localization

Dense visual areas such as waveforms, automation lanes and piano rolls may use custom rendering and virtualization rather than one UI control per item.

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

## 🗂️ Planned Repository Structure

```text
OpenTune/
├── engine/
│   ├── build.zig
│   ├── build.zig.zon
│   └── src/
│       ├── audio/
│       ├── dsp/
│       ├── graph/
│       ├── mixer/
│       ├── midi/
│       ├── project/
│       └── main.zig
│
├── interop/
│   ├── opentune_engine.h
│   └── generated/
│
├── ui/
│   └── OpenTune.UI/
│       ├── Models/
│       ├── ViewModels/
│       ├── Views/
│       ├── Controls/
│       ├── Rendering/
│       └── Interop/
│
├── tests/
│   ├── audio/
│   ├── dsp/
│   ├── project/
│   └── interop/
│
├── docs/
├── examples/
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── LICENSE
└── README.md
```

---

## 🛠️ Building from Source

### Requirements

- Zig
- .NET SDK
- Git
- Platform-specific audio development tools
- A supported desktop operating system

### Build the Zig Engine

```bash
cd engine
zig build
```

### Restore the .NET UI

```bash
dotnet restore ui/OpenTune.UI/OpenTune.UI.csproj
```

### Run the UI

```bash
dotnet run --project ui/OpenTune.UI/OpenTune.UI.csproj
```

The build and packaging workflow is still evolving during the pre-alpha phase.

The final application will package the Avalonia frontend together with the correct native Zig engine for each target platform.

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
- Build the Zig engine library
- Connect the engine to C#
- Open an audio device
- Produce and capture audio
- Create a basic Avalonia application shell

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

- Zig audio development
- DSP algorithms
- Avalonia UI
- C# application architecture
- C ABI design
- MIDI support
- Testing
- Documentation
- Accessibility
- Localization
- Sound design
- User experience research

Before contributing large architectural changes, please open an issue or design discussion.

Please keep the following principles in mind:

- Do not block the real-time audio thread.
- Do not allocate memory in real-time processing paths.
- Do not expose Zig implementation details through the public ABI.
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
