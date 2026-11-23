# OpenTune Architecture and Development Contract

Status: proposed architecture baseline  
Target: OpenTune on `main`  
Core language: Zig  
UI language: TypeScript/JavaScript + CSS  
License: GPL-3.0

## Product objective

Build an independent, open, professional DAW combining a traditional arrangement workflow with clip-based live performance, deep instrument/effect racks, graph-based patching, a large efficient asset library, and user-extensible UI and audio building blocks.

This document is a design contract, not a claim that every subsystem is already implemented. Implementation status must be verified against source and tests.

## Non-negotiable boundaries

1. The real-time audio callback must never wait on UI, disk, network, plugin loading, unbounded queues, or blocking locks.
2. Audio-thread work must be bounded. Allocate, decode, compile, and prepare resources outside the callback; publish prepared state through a bounded handoff.
3. UI rendering and UI logic must not run on the audio thread. UI themes and custom widgets must not be able to access engine memory directly.
4. Treat project files, asset manifests, imported media, presets, and plugins as untrusted input.
5. A graph must be validated before activation: validate port types, channel layouts, node limits, cycles, latency, memory requirements, and processing cost.
6. Graph edits are built off-thread and switched at a safe processing boundary. Retire old graphs only after the audio thread can no longer access them.
7. The engine must have a defined overload and failure policy. A processor that reports or triggers a fault must not be allowed to corrupt buffers or continue with invalid state. Do not claim absolute crash-proofing.
8. All features need reproducible tests and measurable acceptance criteria before performance claims are made.

## Target architecture

### Native engine (Zig)

- Core types, sample formats, buffers, bounded queues, and real-time diagnostics.
- DSP primitives and instrument/effect processors.
- Audio graph model, validation, scheduling plan, preallocated scratch buffers, and routing.
- Audio engine, transport, sample-accurate event scheduling, mixing, metering, and offline rendering.
- MIDI events, automation, project serialization, undo/redo, and version migrations.
- Platform audio backends behind a stable interface.
- Plugin boundary with explicit capabilities, resource limits, and fault isolation where possible.

### UI shell (TypeScript + CSS)

- Arrangement timeline and clip/session workflow.
- Mixer, piano roll, automation editor, browser, rack, and node patch editor.
- Theme tokens, layout definitions, accessible controls, and user-editable extensions.
- A narrow typed command/event protocol to the native engine.
- WebGPU/canvas acceleration where supported, with fallback paths. CSS alone does not guarantee that every UI operation is GPU-rendered; profile layout, scripting, and paint costs separately.

### Asset service

- Content-addressed asset IDs and versioned manifests.
- Background downloads and decompression, integrity checks, and resumable transfers.
- Bounded RAM cache plus optional disk cache and explicit storage budgets.
- Offline availability indicators and predictable missing-asset behavior.
- Network activity never occurs on the audio callback. GitHub may host public releases/manifests, but should not be treated as a guaranteed low-latency streaming CDN; use versioned releases and mirrors/CDN-compatible URLs.
- Prefer efficient synthesis and compact multisample formats when they provide better quality-per-byte than storing raw audio. Lossless and lossy formats must be selected per asset role and quality target.

### Graph and rack model

- One typed graph model shared by instruments, effects, modulation, and user-created processors where practical.
- Distinguish audio-rate, control-rate, event/MIDI, and parameter connections.
- Validate feedback explicitly. Reject accidental cycles; support feedback only with a defined delay and stability policy.
- Racks are reusable subgraphs with parameters, macro mappings, preset state, and deterministic serialization.
- User graphs compile to a bounded execution plan; do not interpret arbitrary unbounded user code in the real-time callback.

### User-created instruments and effects

- Drag-and-drop nodes define a typed DSP graph.
- A builder validates graph shape, resource budgets, and parameter ranges before activation.
- Prefer generated native code or a bounded runtime for supported nodes. Compilation and loading happen off the audio thread.
- Third-party or user-supplied native plugins cannot be made fully safe by an in-process wrapper alone. Use a separate process for high-risk plugins when feasible, with explicit latency and failure trade-offs.
- UI extensions run in a sandboxed extension boundary and cannot mutate engine internals.

## Performance and reliability requirements

- No allocation, file I/O, network I/O, blocking mutex, or unbounded work in the audio callback.
- At 48 kHz, a 128-frame buffer represents about 2.667 ms; this is a deadline budget, not a promise that all processing fits in that time.
- Record callback duration, deadline misses, xruns, queue saturation, and per-node processing cost using non-blocking telemetry.
- Adapt by reducing optional oversampling/quality, suspending nonessential analysis, or refusing activation of an over-budget graph. Never silently change sound quality without a defined policy or user-visible status.
- Prepare graph changes and resource loading away from the callback; switch only at safe boundaries.
- Use deterministic offline render tests, numerical DSP tests, fuzzing of parsers, sanitizer-enabled development builds, and long-running stress tests.
- A process boundary is the strongest practical containment for native plugin crashes. An in-process engine cannot promise recovery from every memory-safety fault or operating-system/driver failure.

### Current real-time core contract

The initial engine implementation enforces these callback boundaries:

- Engine configuration fixes the sample rate, maximum frames per block, and maximum channel count before processing starts.
- Only non-empty, correctly sized planar buffers are accepted by the initial processing path. Storage length, channel count, sample rate, and frame count are validated. Interleaved buffers are rejected until a stride-aware view API exists.
- Callback sample rate and reported frame count must match the output buffer and configured engine rate. The engine enforces a configured maximum block size and channel count.
- Invalid callback metadata fails closed: output is cleared, the audio-thread-owned fault field is set, and transport does not advance.
- A null engine user-data pointer clears output without dereferencing it.
- Processor callbacks are contractually bounded, allocation-free, non-blocking, and free of I/O/logging. This is a contract, not a runtime sandbox.
- Processors receive a local copy of the validated buffer descriptor; the sample storage remains shared for in-place audio processing. Engine transport accounting uses the original validated frame count.
- Processor installation and reset are only safe while the device is stopped or at an explicitly synchronized boundary.
- The diagnostic fault field is audio-thread-owned. Read it only after stopping/synchronizing the callback; cross-thread telemetry will use atomics or a bounded queue in a later stage.

The current core does not yet provide a real hardware backend, atomic graph replacement, plugin fault isolation, or callback timing/xrun telemetry. These are separate acceptance gates.

### Bounded SPSC communication

The core provides a generic `SpscQueue(T, capacity)` for one producer and one consumer:

- Capacity is a compile-time power of two greater than one; storage is embedded in the queue.
- `tryPush` and `tryPop` are bounded, non-blocking operations. A full queue returns `false`; an empty queue returns `null`. Neither operation waits or allocates.
- Producer and consumer own separate native-word wrapping counters. Release publication makes a written slot visible; acquire observation protects both reading the payload and reusing a consumed slot.
- Counters are separated by target cache-line alignment to reduce false sharing.
- The queue is strictly SPSC. Multiple producers or consumers, copying the queue after use, resetting it while active, or destroying it while either side is running are invalid.
- Payload ownership remains the caller's responsibility. Copying a pointer or slice into the queue does not extend the pointed-to data lifetime.
- No concurrent length snapshot is exposed. Callers should use the operation results rather than treat an approximate occupancy value as synchronization.

The test suite verifies FIFO order, full/empty behavior, wraparound at the counter boundary, and concurrent producer/consumer transfer of 200,000 ordered values. The concurrent test passed ThreadSanitizer on the Linux x86_64 development host. The real-time test target also cross-compiled for Windows x86_64 and Linux ARM64; those cross-compiles do not claim runtime validation on those platforms.

### Parameter communication

The engine exposes a bounded parameter bus between one control producer and the audio callback:

- ParameterEvent is a fixed-size value containing a stable parameter ID, finite f32 value, and block-relative frame offset. It carries no pointers, strings, slices, or heap-owned payloads.
- The control producer submits through AudioEngine.sendParameter; invalid values/offsets and queue saturation are reported synchronously.
- The audio callback consumes at most 64 events per block. Work is bounded even when the producer floods the queue.
- Events whose frame offset is outside the actual next block are dropped and counted. They are not silently deferred into a later block.
- A fixed-capacity ParameterRegistry stores stable nonzero IDs and finite min/max/default values. Duplicate IDs, invalid ranges, unknown IDs, and out-of-range values are rejected on the control side. Register definitions before starting the device; do not mutate the registry while the audio thread is active.
- ParameterEvent is a fixed-size value containing ID, finite value, block-relative frame offset, ramp duration, and ramp mode. It carries no pointers, strings, slices, or heap-owned payloads.
- The audio callback consumes at most 64 events per block, stable-sorts them by frame offset using bounded insertion sort, and divides rendering into spans ending exactly at event offsets. Events at the same offset are applied in FIFO submission order before the next span.
- Sample-accurate processors provide both an event handler and a process_segment callback. The latter receives the full validated planar buffer plus a start-frame/count window; AudioBuffer.channelRange provides bounded channel slices for that window. Legacy processors without this interface cannot consume parameter events; those events are counted as dropped rather than applied at an imprecise time.
- Ramp supports step, linear, and positive-domain exponential transitions. Coefficients are prepared when a target changes; advance performs bounded per-sample updates without allocation or transcendental math in the sample loop. Exponential ramps reject non-positive endpoints. Ramps reduce abrupt parameter discontinuities but do not guarantee click-free output for every processor or parameter.
- Atomic counters expose accepted, invalid, full, dispatched, and dropped totals as diagnostic snapshots. They are not a transactional multi-counter snapshot.
- The bus is SPSC: exactly one control producer and the audio thread as consumer. Multiple UI/MIDI producers must be serialized by a control-side aggregator or assigned separate queues in a future design.

## Asset size and streaming requirements

- Use a content-addressed catalogue with checksums, licenses, sample rate, channels, loop points, loudness metadata, and codec information.
- Separate essential factory content from optional downloadable packs.
- Support local-first playback, prefetching, RAM/disk cache quotas, download prioritization, and cancellation.
- Never rely on fetching an uncached asset at the exact moment it is needed for real-time playback.
- Define measurable targets for cold-start size, installed factory library size, cache use, first-use latency, and offline behavior before selecting codecs.

## Development protocol

Every stage follows the same four steps:

1. Design: inspect the current code, define scope, interfaces, risks, and acceptance criteria.
2. Verify: compare the implementation and repository state against the design; do not infer success from a green build alone.
3. Test, debug, and audit: run formatting, build, unit/integration tests, static checks, security/fuzz checks where relevant, and benchmarks. Rework the design up to five iterations if criteria are not met; record each iteration and evidence.
4. Final review and commit: inspect the final diff, confirm tests and limitations, update docs, and commit to `main`.

Do not create additional branches unless explicitly requested. Never report a test, benchmark, audit, or commit as completed unless its result was actually observed.

## Proposed implementation sequence

1. Baseline audit: enumerate existing modules, build configuration, Zig version, tests, CI, and current known limitations.
2. Real-time core: process context, buffer contracts, bounded queue, fault/status reporting, callback-safety tests.
3. Audio graph: typed ports, graph validation, scheduling plan, scratch-buffer planning, safe graph handoff.
4. Engine and backend: callback integration, transport, metering, xrun diagnostics, device tests.
5. DSP foundation: oscillators, envelopes, filters, dynamics, resampling, SIMD and numerical correctness tests.
6. MIDI, automation, and project format.
7. Rack and node editor model, including serialization and validation.
8. UI shell and GPU-assisted rendering, connected through the narrow engine protocol.
9. Factory instruments/effects and content-addressed asset catalogue.
10. Cache/download manager and offline-first asset streaming.
11. User-built instruments/effects, extension security, and plugin hosting/isolation.
12. Production hardening: profiling, fuzzing, long-run stability, compatibility, documentation, packaging.

## Acceptance gates

A stage is complete only when:
- its acceptance criteria are written down;
- relevant tests are present and pass in the observed environment;
- real-time safety has been reviewed for audio-path changes;
- performance claims include workload, hardware, sample rate, block size, and measured results;
- known limitations and recovery behavior are documented;
- the final diff has been reviewed and committed to `main`.
