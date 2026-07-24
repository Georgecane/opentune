# Contributing to OpenTune

Thank you for your interest in contributing to OpenTune.

OpenTune is an early-stage, free and open-source Digital Audio Workstation built around a native Zig audio engine and a C#/.NET application with Avalonia UI.

The project is still in pre-alpha, so architecture, APIs, project formats and development workflows may change. Contributions that improve the foundation, reliability and clarity of the project are especially valuable.

---

## Before You Start

Please read the following documents before contributing:

- [README.md](README.md) — project overview and roadmap
- [SECURITY.md](SECURITY.md) — vulnerability reporting and security boundaries
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — community expectations, when available

For large architectural changes, open a design discussion or issue before writing a large implementation.

---

## What You Can Contribute

Contributions are welcome in many areas:

- Zig audio-engine development
- Real-time audio processing
- DSP algorithms
- Audio graph and routing
- MIDI support
- File-format support
- C ABI design
- C#/.NET application architecture
- Avalonia UI and custom controls
- Timeline, waveform and piano-roll rendering
- Accessibility
- Localization
- Testing and fuzzing
- Documentation
- Build and release automation
- Performance analysis
- User experience research

You do not need to work on the audio engine to make a useful contribution. Documentation, tests, issue reports and reproducible bug reports are all important.

---

## Development Principles

### Real-Time Audio Comes First

The real-time audio path must remain predictable.

Do not add the following to the audio callback or other real-time processing paths:

- Unbounded memory allocation
- Blocking mutexes or waits
- File-system access
- Network access
- UI calls
- Calls into the .NET runtime
- Unbounded logging
- Plugin scanning
- Dynamic project loading
- Operations with unpredictable execution time

Use preallocated buffers, bounded queues, atomics and explicit processing limits.

### Keep the Engine and UI Separate

The Zig engine and Avalonia UI communicate through the C ABI and explicit application commands.

Avoid exposing:

- Zig implementation types
- Internal pointers
- Zig allocators
- Unstable structs
- Unversioned ABI functions
- Managed .NET objects to the engine

The audio engine must not depend on Avalonia or UI-specific concepts.

### Prefer Simple, Explicit Designs

OpenTune values code that is easy to understand, test and maintain.

When choosing between a clever optimization and a simple design, prefer the simple design unless profiling demonstrates a real problem.

### Measure Before Optimizing

Performance changes should include evidence whenever practical:

- Benchmark results
- CPU usage measurements
- Allocation measurements
- Audio callback timing
- Memory usage
- Before-and-after comparisons

Do not optimize based only on assumptions.

---

## Repository Structure

The planned repository structure is:

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
├── docs/
└── examples/
```

The structure may change as the project evolves. Keep new code close to the subsystem it belongs to.

---

## Setting Up the Development Environment

### Required Tools

- Git
- Zig
- .NET SDK
- A supported desktop operating system
- Platform-specific audio development tools when required

### Clone the Repository

```bash
git clone https://github.com/OWNER/OpenTune.git
cd OpenTune
```

Replace `OWNER` with the actual repository owner.

### Build the Zig Engine

```bash
cd engine
zig build
```

### Restore and Build the .NET Application

From the repository root:

```bash
dotnet restore ui/OpenTune.UI/OpenTune.UI.csproj
dotnet build ui/OpenTune.UI/OpenTune.UI.csproj
```

### Run the Application

```bash
dotnet run --project ui/OpenTune.UI/OpenTune.UI.csproj
```

The exact commands and project paths may change while the build system is being established.

---

## Formatting and Static Checks

Before opening a pull request, format and validate all affected code.

### Zig

```bash
zig fmt engine interop
zig build
```

### .NET and C#

```bash
dotnet format ui/OpenTune.UI/OpenTune.UI.csproj
dotnet build ui/OpenTune.UI/OpenTune.UI.csproj
```

Do not commit generated binaries, temporary build output, local IDE settings or private files.

---

## Testing Requirements

Every meaningful code change should include appropriate testing.

### Zig and Audio Engine Tests

Use tests for:

- DSP algorithms
- Audio graph behavior
- Mixer and routing
- Transport timing
- Buffer boundaries
- Sample-rate handling
- Channel layouts
- Project parsing
- Serialization and deserialization
- Error handling
- ABI functions

DSP tests should be deterministic and should not require the graphical application.

### Offline Rendering Tests

For important audio-processing changes, prefer deterministic offline rendering tests.

A test should be able to:

1. Create a known input signal.
2. Process it through the engine.
3. Render the output.
4. Compare the result against expected values or a controlled reference.

Small floating-point differences should be handled with appropriate tolerances.

### C# and UI Tests

Test:

- View-model behavior
- Commands and undo/redo
- Project operations
- Interop marshaling
- Settings and validation
- Keyboard interactions
- Accessibility-sensitive behavior
- Platform-specific behavior where practical

### Manual Audio Testing

When a change affects real-time audio, also test manually with:

- Different sample rates
- Different buffer sizes
- Mono and stereo devices
- Audio input and output
- Device changes while the application is running
- Start, stop and restart operations
- Long playback sessions
- CPU load and audio dropouts

---

## Audio-Specific Review Rules

Before submitting audio-engine changes, verify that:

- The audio callback performs no allocation.
- The audio callback does not block.
- The audio callback does not perform file or network I/O.
- The audio callback does not call into .NET or Avalonia.
- All buffers have clear ownership.
- Buffer sizes and channel counts are validated.
- Processing behavior is defined for silence and missing input.
- NaN and infinity handling is considered where relevant.
- Denormal-number behavior is considered for long-running DSP.
- Error reporting does not depend on logging from the real-time thread.
- Any new command or event has a bounded representation.

If a change intentionally violates one of these rules, explain why in the pull request and include measurements or design justification.

---

## C ABI and Interop Guidelines

The C ABI is a security, stability and compatibility boundary.

When changing the ABI:

- Document the change.
- Consider ABI versioning.
- Add or update C header declarations.
- Validate struct sizes.
- Use fixed-width integer types where appropriate.
- Define ownership and lifetime rules.
- Define which side allocates and frees memory.
- Avoid passing strings without an explicit encoding and lifetime contract.
- Avoid exposing pointers to temporary or internal data.
- Add an interop test.
- Consider compatibility with older UI builds.

Do not silently change the layout of a public ABI struct.

---

## UI Development Guidelines

Avalonia UI code should follow these principles:

- Keep business logic in models and view models.
- Keep views focused on presentation and user interaction.
- Avoid putting engine logic directly in controls.
- Use commands for user actions.
- Keep keyboard navigation in mind.
- Support high-DPI displays.
- Consider accessibility when adding custom controls.
- Avoid creating one heavyweight control for every timeline clip or waveform item.
- Use virtualization for large projects.
- Keep rendering work separate from real-time audio processing.

The UI should remain responsive while files are loading, waveforms are generated or projects are being saved.

---

## Adding Dependencies

Before adding a dependency, consider:

- Is it necessary?
- Is it actively maintained?
- Is its license compatible with OpenTune?
- Does it contain native code?
- Does it add platform-specific build requirements?
- Does it allocate or block in a real-time path?
- Does it increase binary size significantly?
- Does it introduce network access or telemetry?
- Does it have known security advisories?
- Can the functionality be implemented clearly without another dependency?

Dependency additions should be explained in the pull request.

Do not add a dependency only for convenience when it would introduce unnecessary complexity into the audio engine or ABI layer.

---

## Issues and Feature Requests

Before opening an issue, search existing issues and discussions.

### Bug Reports

A useful bug report should include:

- A clear title
- OpenTune version or commit
- Operating system and architecture
- Audio device and driver information
- Sample rate and buffer size
- Steps to reproduce
- Expected behavior
- Actual behavior
- Logs or crash information
- A minimal project or test case when possible

Do not attach private recordings, credentials or sensitive project files.

### Feature Requests

Feature requests should explain:

- The problem being solved
- The intended user workflow
- Why existing functionality is insufficient
- Possible implementation considerations
- Whether the feature affects the real-time engine, ABI, project format or UI

### Security Issues

Do not open a public issue for a security vulnerability. Follow [SECURITY.md](SECURITY.md).

---

## Branches and Pull Requests

Use focused branches with descriptive names:

```text
feat/midi-piano-roll
fix/windows-device-reconnect
docs/update-build-guide
perf/waveform-cache
refactor/engine-commands
test/project-parser
build/ci-audio-matrix
```

Avoid unrelated changes in the same branch.

### Pull Request Requirements

A pull request should:

- Explain what changed.
- Explain why the change is needed.
- Identify affected subsystems.
- Include tests or explain why tests are not applicable.
- Include performance measurements for performance-sensitive changes.
- Mention platform-specific behavior.
- Mention ABI or project-format changes.
- Update documentation when behavior changes.
- Keep generated files and unrelated formatting changes out of the diff.

A pull request may be rejected or sent back for revision if it introduces an unacceptable real-time, security, licensing or maintenance risk.

---

## Commit Messages

Use clear and focused commit messages. The project follows a Conventional Commits-style format where practical:

```text
feat(audio): add stereo output stream
fix(interop): validate engine handle lifetime
docs(readme): describe Zig and Avalonia architecture
test(dsp): add oscillator rendering test
perf(waveform): reduce peak-cache allocations
refactor(ui): move transport commands into view model
build(ci): add Linux engine build
```

Keep commits small enough to review. Avoid mixing a feature, a large refactor and unrelated formatting changes in one commit.

---

## Project and File Format Changes

Project files are user data and should be treated as a compatibility contract.

When changing the project format:

- Update the format version.
- Document the migration behavior.
- Preserve backward compatibility when practical.
- Add loading tests for older versions.
- Avoid silently discarding user data.
- Handle missing media safely.
- Validate paths and external references.
- Update example projects if necessary.

Never commit user recordings, copyrighted sample libraries or private projects to the repository without explicit permission and appropriate licensing.

---

## Licensing Contributions

OpenTune is licensed under the GNU General Public License v3.0.

By submitting a contribution, you agree that the contribution may be distributed as part of OpenTune under the project’s license and repository terms.

You must have the right to submit the code, documentation, artwork, audio or other material that you contribute.

Do not submit:

- Code copied from incompatible licenses
- Unlicensed third-party code
- Commercial sample content without permission
- Trademarks or logos without authorization
- Personal data or confidential material
- Generated code whose license prevents redistribution

Third-party dependencies and content may have separate licenses. Review and document them appropriately.

---

## Review Expectations

Reviewers may evaluate contributions for:

- Correctness
- Real-time safety
- Memory ownership
- ABI stability
- Cross-platform behavior
- Security impact
- Performance
- Test coverage
- Accessibility
- Maintainability
- License compatibility
- Documentation quality

Technical disagreement is normal. Keep discussions focused on the design, evidence and project goals.

---

## Community Conduct

Please be respectful, constructive and welcoming.

Do not engage in harassment, discrimination, personal attacks, deliberate disruption or bad-faith behavior.

The project will follow the rules described in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) once that document is added.

---

## Recognition

Contributors may be credited in release notes, documentation or project acknowledgements when appropriate.

If you do not want to be credited publicly, mention this in your contribution or contact the maintainers.

---

## Questions

For general development questions, use a public issue or discussion when the answer may help other contributors.

For sensitive matters, private reports and security concerns, follow [SECURITY.md](SECURITY.md).

Thank you for helping build OpenTune.
