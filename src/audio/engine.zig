const std = @import("std");
const types = @import("../core/types.zig");
const buffer = @import("../core/audio_buffer.zig");
const device = @import("device.zig");

pub const Processor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    /// Must be bounded, allocation-free, non-blocking, and free of I/O/logging.
    /// Processor state is owned by the audio thread while the device is running.
    pub const VTable = struct {
        process: *const fn (*anyopaque, *buffer.AudioBuffer, *const types.ProcessContext) void,
        reset: *const fn (*anyopaque, *const types.ProcessContext) void,
    };

    pub fn process(
        self: *Processor,
        output: *buffer.AudioBuffer,
        context: *const types.ProcessContext,
    ) void {
        self.vtable.process(self.ptr, output, context);
    }

    /// Call only while the device is stopped or at a synchronized processing boundary.
    pub fn reset(self: *Processor, context: *const types.ProcessContext) void {
        self.vtable.reset(self.ptr, context);
    }
};

pub const ProcessFault = enum {
    none,
    invalid_engine_config,
    invalid_sample_rate,
    invalid_channel_count,
    invalid_block_size,
    oversized_block,
    malformed_buffer,
    unsupported_layout,
    invalid_callback_context,
};

pub const Config = struct {
    sample_rate: types.SampleRate = 48_000,
    max_block_size: types.FrameCount = 128,
    max_channels: types.ChannelCount = 2,

    pub fn isValid(self: Config) bool {
        return self.sample_rate > 0 and
            self.max_block_size > 0 and
            self.max_channels > 0;
    }
};

pub const AudioEngine = struct {
    config: Config,
    context: types.ProcessContext,
    processor: ?Processor = null,

    /// Audio-thread-owned diagnostic. Read it only after the callback is stopped
    /// or through a future atomic telemetry interface.
    last_fault: ProcessFault = .none,

    pub fn init(sample_rate: types.SampleRate, max_block_size: types.FrameCount) AudioEngine {
        const config = Config{
            .sample_rate = sample_rate,
            .max_block_size = max_block_size,
        };
        return .{
            .config = config,
            .context = .{
                .sample_rate = sample_rate,
                .block_size = max_block_size,
                .transport_sample = 0,
            },
        };
    }

    pub fn initWithConfig(config: Config) types.Result!AudioEngine {
        if (!config.isValid()) return error.InvalidArgument;
        var engine = init(config.sample_rate, config.max_block_size);
        engine.config = config;
        return engine;
    }

    /// Install or replace processors only while the device is stopped. Runtime
    /// graph/processor replacement will use an explicit bounded handoff later.
    pub fn setProcessor(self: *AudioEngine, processor: Processor) void {
        self.processor = processor;
    }

    /// Reset processor and transport only while the device is stopped or at a
    /// synchronized processing boundary.
    pub fn reset(self: *AudioEngine) void {
        self.context.block_size = self.config.max_block_size;
        self.context.transport_sample = 0;
        if (self.processor) |*processor| {
            processor.reset(&self.context);
        }
        self.last_fault = .none;
    }

    /// Processes one bounded planar block. This function performs no allocation,
    /// locking, file/network I/O, logging, or unbounded queue operations.
    /// On invalid metadata it clears the supplied buffer and leaves transport
    /// unchanged. Processor panics and arbitrary memory corruption are not caught.
    pub fn process(self: *AudioEngine, output: *buffer.AudioBuffer) void {
        self.last_fault = .none;

        if (!self.config.isValid()) {
            self.fail(.invalid_engine_config, output);
            return;
        }
        if (output.sample_rate != self.config.sample_rate) {
            self.fail(.invalid_sample_rate, output);
            return;
        }
        if (output.channels == 0 or output.channels > self.config.max_channels) {
            self.fail(.invalid_channel_count, output);
            return;
        }
        if (output.frames == 0) {
            self.fail(.invalid_block_size, output);
            return;
        }
        if (output.frames > self.config.max_block_size) {
            self.fail(.oversized_block, output);
            return;
        }
        if (output.layout != .planar) {
            self.fail(.unsupported_layout, output);
            return;
        }
        if (!output.hasValidStorage()) {
            self.fail(.malformed_buffer, output);
            return;
        }

        const block_frames = output.frames;
        self.context.block_size = block_frames;

        if (self.processor) |*processor| {
            // Give processors a local descriptor copy. They can write the
            // prevalidated sample storage but cannot mutate the backend's
            // original buffer metadata or the engine's transport accounting.
            var processor_output = output.*;
            processor.process(&processor_output, &self.context);
        } else {
            output.clear();
        }

        self.context.transport_sample +|= block_frames;
    }

    /// Device callbacks must provide the negotiated sample rate and the actual
    /// frame count. A null user_data pointer is handled without dereferencing it.
    pub fn deviceCallback(
        user_data: ?*anyopaque,
        _: ?*const device.AudioBuffer,
        output: *device.AudioBuffer,
        callback_context: *const types.ProcessContext,
    ) void {
        const raw_engine = user_data orelse {
            output.clear();
            return;
        };

        const engine: *AudioEngine = @ptrCast(@alignCast(raw_engine));
        if (callback_context.sample_rate != engine.config.sample_rate or
            callback_context.block_size != output.frames)
        {
            engine.fail(.invalid_callback_context, output);
            return;
        }

        engine.process(output);
    }

    fn fail(self: *AudioEngine, fault: ProcessFault, output: *buffer.AudioBuffer) void {
        output.clear();
        self.last_fault = fault;
    }
};

test "engine advances transport by actual valid block frames" {
    var samples: [8]f32 = undefined;
    @memset(&samples, 0);
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 8);
    engine.process(&out);
    try std.testing.expectEqual(@as(u64, 4), engine.context.transport_sample);
    try std.testing.expectEqual(@as(u32, 4), engine.context.block_size);
    try std.testing.expectEqual(ProcessFault.none, engine.last_fault);
}

test "engine rejects invalid sample rate, empty blocks, and invalid initialization" {
    var engine = AudioEngine.init(48_000, 8);

    var wrong_rate_samples = [_]f32{ 1, 1, 1, 1 };
    var wrong_rate = buffer.AudioBuffer.init(&wrong_rate_samples, 2, 44_100);
    engine.process(&wrong_rate);
    try std.testing.expectEqual(ProcessFault.invalid_sample_rate, engine.last_fault);
    for (wrong_rate.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);

    var empty_samples: [0]f32 = .{};
    var empty = buffer.AudioBuffer.init(&empty_samples, 2, 48_000);
    engine.process(&empty);
    try std.testing.expectEqual(ProcessFault.invalid_block_size, engine.last_fault);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);

    var invalid_engine = AudioEngine.init(0, 0);
    var valid_samples = [_]f32{ 1, 1 };
    var valid_output = buffer.AudioBuffer.init(&valid_samples, 2, 48_000);
    invalid_engine.process(&valid_output);
    try std.testing.expectEqual(ProcessFault.invalid_engine_config, invalid_engine.last_fault);
    for (valid_output.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}

test "engine rejects a block larger than its configured maximum" {
    var samples: [12]f32 = undefined;
    @memset(&samples, 1);
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 4);
    engine.process(&out);
    try std.testing.expectEqual(ProcessFault.oversized_block, engine.last_fault);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}

test "engine rejects channel counts above its configured maximum" {
    var samples: [12]f32 = undefined;
    @memset(&samples, 1);
    var out = buffer.AudioBuffer.init(&samples, 3, 48_000);
    var engine = try AudioEngine.initWithConfig(.{ .max_channels = 2 });
    engine.process(&out);
    try std.testing.expectEqual(ProcessFault.invalid_channel_count, engine.last_fault);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}

test "engine rejects malformed and unsupported buffers" {
    var malformed_samples = [_]f32{ 1, 2, 3, 4, 5 };
    var malformed = buffer.AudioBuffer.init(&malformed_samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 8);
    engine.process(&malformed);
    try std.testing.expectEqual(ProcessFault.malformed_buffer, engine.last_fault);
    for (malformed.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);

    var interleaved_samples = [_]f32{ 1, 2, 3, 4 };
    var interleaved = buffer.AudioBuffer.init(&interleaved_samples, 2, 48_000);
    interleaved.layout = .interleaved;
    engine.process(&interleaved);
    try std.testing.expectEqual(ProcessFault.unsupported_layout, engine.last_fault);
}

test "engine rejects invalid configuration" {
    try std.testing.expectError(
        error.InvalidArgument,
        AudioEngine.initWithConfig(.{ .sample_rate = 0 }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        AudioEngine.initWithConfig(.{ .max_block_size = 0 }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        AudioEngine.initWithConfig(.{ .max_channels = 0 }),
    );
}

test "device callback rejects mismatched context and clears output" {
    var samples = [_]f32{ 1, 2, 3, 4 };
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 128);
    const wrong_context = types.ProcessContext{
        .sample_rate = 44_100,
        .block_size = 2,
        .transport_sample = 0,
    };

    AudioEngine.deviceCallback(&engine, null, &out, &wrong_context);
    try std.testing.expectEqual(ProcessFault.invalid_callback_context, engine.last_fault);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);

    @memset(out.samples, 1);
    const wrong_frames = types.ProcessContext{
        .sample_rate = 48_000,
        .block_size = 1,
        .transport_sample = 0,
    };
    AudioEngine.deviceCallback(&engine, null, &out, &wrong_frames);
    try std.testing.expectEqual(ProcessFault.invalid_callback_context, engine.last_fault);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}

test "device callback clears output when engine user data is missing" {
    var samples = [_]f32{ 1, 2, 3, 4 };
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    const callback_context = types.ProcessContext{
        .sample_rate = 48_000,
        .block_size = 2,
        .transport_sample = 0,
    };

    AudioEngine.deviceCallback(null, null, &out, &callback_context);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}

test "processor receives bounded block context and sample-accurate transport" {
    const Probe = struct {
        calls: u32 = 0,
        last_block_size: u32 = 0,
        last_transport_sample: u64 = 0,

        fn process(ptr: *anyopaque, output: *buffer.AudioBuffer, context: *const types.ProcessContext) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.calls += 1;
            self.last_block_size = context.block_size;
            self.last_transport_sample = context.transport_sample;
            @memset(output.samples, 0.25);
            output.frames = 0;
            output.channels = 0;
            output.sample_rate = 0;
            output.layout = .interleaved;
        }

        fn reset(ptr: *anyopaque, context: *const types.ProcessContext) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.last_block_size = context.block_size;
            self.last_transport_sample = context.transport_sample;
        }
    };

    var probe = Probe{};
    const vtable = Processor.VTable{
        .process = Probe.process,
        .reset = Probe.reset,
    };
    const processor = Processor{ .ptr = &probe, .vtable = &vtable };
    var engine = AudioEngine.init(48_000, 8);
    engine.setProcessor(processor);

    var first_samples: [4]f32 = undefined;
    var first = buffer.AudioBuffer.init(&first_samples, 2, 48_000);
    engine.process(&first);
    try std.testing.expectEqual(@as(u32, 2), probe.last_block_size);
    try std.testing.expectEqual(@as(u64, 0), probe.last_transport_sample);
    try std.testing.expectEqual(@as(u64, 2), engine.context.transport_sample);
    try std.testing.expectEqual(@as(u32, 2), first.frames);
    try std.testing.expectEqual(@as(u32, 2), first.channels);
    try std.testing.expectEqual(@as(u32, 48_000), first.sample_rate);
    try std.testing.expectEqual(types.AudioLayout.planar, first.layout);
    for (first.samples) |sample| try std.testing.expectEqual(@as(f32, 0.25), sample);

    var second_samples: [6]f32 = undefined;
    var second = buffer.AudioBuffer.init(&second_samples, 2, 48_000);
    engine.process(&second);
    try std.testing.expectEqual(@as(u32, 3), probe.last_block_size);
    try std.testing.expectEqual(@as(u64, 2), probe.last_transport_sample);
    try std.testing.expectEqual(@as(u64, 5), engine.context.transport_sample);
    try std.testing.expectEqual(@as(u32, 2), probe.calls);

    engine.reset();
    try std.testing.expectEqual(@as(u32, 8), probe.last_block_size);
    try std.testing.expectEqual(@as(u64, 0), probe.last_transport_sample);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
}
