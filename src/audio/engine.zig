const std = @import("std");
const types = @import("../core/types.zig");
const buffer = @import("../core/audio_buffer.zig");
const device = @import("device.zig");
const parameter = @import("../core/parameter.zig");
const parameter_registry = @import("../core/parameter_registry.zig");

pub const Processor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    on_parameter: ?*const fn (*anyopaque, parameter.ParameterEvent, *const types.ProcessContext) void = null,

    /// Must be bounded, allocation-free, non-blocking, and free of I/O/logging.
    /// Processor state is owned by the audio thread while the device is running.
    pub const VTable = struct {
        process: *const fn (*anyopaque, *buffer.AudioBuffer, *const types.ProcessContext) void,
        reset: *const fn (*anyopaque, *const types.ProcessContext) void,
        /// When parameter events are pending, this replaces process for the block.
        /// It must render only [start_frame, start_frame + frame_count) in the shared buffer.
        process_segment: ?*const fn (*anyopaque, *buffer.AudioBuffer, *const types.ProcessContext, types.FrameCount, types.FrameCount) void = null,
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
    parameter_bus: parameter.ParameterBus = .{},
    parameter_registry: parameter_registry.ParameterRegistry = .{},

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

    /// Submit from the single control producer. Events are relative to the next
    /// audio block and are consumed only by the audio callback.
    /// Register metadata before starting the device. Registry mutation is control-thread-only.
    pub fn registerParameter(self: *AudioEngine, spec: parameter_registry.ParameterSpec) parameter_registry.RegisterResult {
        return self.parameter_registry.register(spec);
    }

    pub fn sendParameter(self: *AudioEngine, event: parameter.ParameterEvent) parameter.SendResult {
        if (!event.isValid(self.config.max_block_size) or
            !self.parameter_registry.validateValue(event.id, event.value))
        {
            _ = self.parameter_bus.rejected_invalid.fetchAdd(1, .monotonic);
            return .invalid_event;
        }
        return self.parameter_bus.send(event, self.config.max_block_size);
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

        // Drain a fixed number of events, discard invalid offsets, then stable-sort
        // by frame offset. The insertion sort is bounded by max_events_per_block.
        var events: [parameter.max_events_per_block]parameter.ParameterEvent = undefined;
        var event_count: usize = 0;
        var drained: usize = 0;
        while (drained < parameter.max_events_per_block) : (drained += 1) {
            const event = self.parameter_bus.receive() orelse break;
            if (event.frame_offset >= block_frames) {
                self.parameter_bus.markDropped();
                continue;
            }
            var insert_at = event_count;
            while (insert_at > 0 and events[insert_at - 1].frame_offset > event.frame_offset) : (insert_at -= 1) {
                events[insert_at] = events[insert_at - 1];
            }
            events[insert_at] = event;
            event_count += 1;
        }

        if (self.processor) |*processor| {
            if (event_count > 0 and
                processor.vtable.process_segment != null and
                processor.on_parameter != null)
            {
                const segment_fn = processor.vtable.process_segment.?;
                const handler = processor.on_parameter.?;
                var cursor: types.FrameCount = 0;
                var event_index: usize = 0;
                while (event_index < event_count) {
                    const event_frame = events[event_index].frame_offset;
                    if (event_frame > cursor) {
                        var segment_output = output.*;
                        segment_fn(processor.ptr, &segment_output, &self.context, cursor, event_frame - cursor);
                    }
                    while (event_index < event_count and events[event_index].frame_offset == event_frame) : (event_index += 1) {
                        handler(processor.ptr, events[event_index], &self.context);
                        self.parameter_bus.markDispatched();
                    }
                    cursor = event_frame;
                }
                if (cursor < block_frames) {
                    var segment_output = output.*;
                    segment_fn(processor.ptr, &segment_output, &self.context, cursor, block_frames - cursor);
                }
            } else {
                for (events[0..event_count]) |_| self.parameter_bus.markDropped();
                var processor_output = output.*;
                processor.process(&processor_output, &self.context);
            }
        } else {
            for (events[0..event_count]) |_| self.parameter_bus.markDropped();
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

test "engine dispatches bounded parameter events before processor rendering" {
    const Probe = struct {
        received: [4]parameter.ParameterEvent = undefined,
        count: usize = 0,
        fn onParameter(ptr: *anyopaque, event: parameter.ParameterEvent, context: *const types.ProcessContext) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            if (event.frame_offset >= context.block_size) return;
            if (self.count < self.received.len) {
                self.received[self.count] = event;
                self.count += 1;
            }
        }
        fn process(_: *anyopaque, output: *buffer.AudioBuffer, _: *const types.ProcessContext) void {
            output.clear();
        }
        fn processSegment(_: *anyopaque, _: *buffer.AudioBuffer, _: *const types.ProcessContext, _: u32, _: u32) void {}
        fn reset(_: *anyopaque, _: *const types.ProcessContext) void {}
    };
    var probe = Probe{};
    const vtable = Processor.VTable{ .process = Probe.process, .reset = Probe.reset, .process_segment = Probe.processSegment };
    const processor = Processor{ .ptr = &probe, .vtable = &vtable, .on_parameter = Probe.onParameter };
    var engine = AudioEngine.init(48_000, 8);
    engine.setProcessor(processor);
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{ .id = 10, .min_value = 0, .max_value = 1, .default_value = 0 }));
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{ .id = 11, .min_value = 0, .max_value = 1, .default_value = 0 }));
    try std.testing.expectEqual(parameter.SendResult.queued, engine.sendParameter(.{ .id = 10, .value = 0.5 }));
    try std.testing.expectEqual(parameter.SendResult.queued, engine.sendParameter(.{ .id = 11, .value = 0.75, .frame_offset = 3 }));
    var samples: [8]f32 = undefined;
    var output = buffer.AudioBuffer.init(&samples, 2, 48_000);
    engine.process(&output);
    try std.testing.expectEqual(@as(usize, 2), probe.count);
    try std.testing.expectEqual(@as(u32, 10), probe.received[0].id);
    try std.testing.expectEqual(@as(u32, 11), probe.received[1].id);
    try std.testing.expectEqual(@as(u64, 2), engine.parameter_bus.telemetry().dispatched);
    try std.testing.expectEqual(@as(u64, 0), engine.parameter_bus.telemetry().dropped);
}

test "engine renders segments at sorted sample-accurate parameter boundaries" {
    const Probe = struct {
        segments: [4][2]u32 = undefined,
        segment_count: usize = 0,
        events: [2]parameter.ParameterEvent = undefined,
        event_count: usize = 0,

        fn onParameter(ptr: *anyopaque, event: parameter.ParameterEvent, _: *const types.ProcessContext) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.events[self.event_count] = event;
            self.event_count += 1;
        }

        fn process(_: *anyopaque, output: *buffer.AudioBuffer, _: *const types.ProcessContext) void {
            output.clear();
        }

        fn processSegment(ptr: *anyopaque, output: *buffer.AudioBuffer, _: *const types.ProcessContext, start: u32, count: u32) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.segments[self.segment_count] = .{ start, count };
            self.segment_count += 1;
            @memset(output.channelRange(0, start, count), @floatFromInt(start));
        }

        fn reset(_: *anyopaque, _: *const types.ProcessContext) void {}
    };

    var probe = Probe{};
    const vtable = Processor.VTable{
        .process = Probe.process,
        .reset = Probe.reset,
        .process_segment = Probe.processSegment,
    };
    var engine = AudioEngine.init(48_000, 8);
    engine.setProcessor(.{ .ptr = &probe, .vtable = &vtable, .on_parameter = Probe.onParameter });
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{
        .id = 21,
        .min_value = 0,
        .max_value = 1,
        .default_value = 0,
    }));
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{
        .id = 22,
        .min_value = 0,
        .max_value = 1,
        .default_value = 0,
    }));

    // Submit out of frame order: the engine must render in ascending offset order.
    try std.testing.expectEqual(parameter.SendResult.queued, engine.sendParameter(.{
        .id = 22,
        .value = 0.8,
        .frame_offset = 5,
    }));
    try std.testing.expectEqual(parameter.SendResult.queued, engine.sendParameter(.{
        .id = 21,
        .value = 0.2,
        .frame_offset = 2,
    }));

    var samples: [16]f32 = undefined;
    @memset(&samples, -1);
    var output = buffer.AudioBuffer.init(&samples, 2, 48_000);
    engine.process(&output);

    try std.testing.expectEqual(@as(usize, 3), probe.segment_count);
    try std.testing.expectEqual([2]u32{ 0, 2 }, probe.segments[0]);
    try std.testing.expectEqual([2]u32{ 2, 3 }, probe.segments[1]);
    try std.testing.expectEqual([2]u32{ 5, 3 }, probe.segments[2]);
    try std.testing.expectEqual(@as(usize, 2), probe.event_count);
    try std.testing.expectEqual(@as(u32, 21), probe.events[0].id);
    try std.testing.expectEqual(@as(u32, 22), probe.events[1].id);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0, 0, 2, 2, 2, 5, 5, 5 }, output.channel(0));
    try std.testing.expectEqual(@as(u64, 2), engine.parameter_bus.telemetry().dispatched);
}

test "engine rejects unregistered and out-of-range parameter values" {
    var engine = AudioEngine.init(48_000, 8);
    try std.testing.expectEqual(parameter.SendResult.invalid_event, engine.sendParameter(.{ .id = 7, .value = 0.5 }));
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{
        .id = 7,
        .min_value = 0,
        .max_value = 1,
        .default_value = 0.5,
    }));
    try std.testing.expectEqual(parameter.SendResult.invalid_event, engine.sendParameter(.{ .id = 7, .value = 1.5 }));
    try std.testing.expectEqual(@as(u64, 2), engine.parameter_bus.telemetry().rejected_invalid);
}

test "engine drops events outside actual block and caps per-block dispatch" {
    const Probe = struct {
        count: usize = 0,
        fn onParameter(ptr: *anyopaque, _: parameter.ParameterEvent, _: *const types.ProcessContext) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.count += 1;
        }
        fn process(_: *anyopaque, output: *buffer.AudioBuffer, _: *const types.ProcessContext) void {
            output.clear();
        }
        fn processSegment(_: *anyopaque, _: *buffer.AudioBuffer, _: *const types.ProcessContext, _: u32, _: u32) void {}
        fn reset(_: *anyopaque, _: *const types.ProcessContext) void {}
    };
    var probe = Probe{};
    const vtable = Processor.VTable{ .process = Probe.process, .reset = Probe.reset, .process_segment = Probe.processSegment };
    const processor = Processor{ .ptr = &probe, .vtable = &vtable, .on_parameter = Probe.onParameter };
    var engine = AudioEngine.init(48_000, 8);
    engine.setProcessor(processor);
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{ .id = 1, .min_value = 0, .max_value = 1, .default_value = 0 }));
    try std.testing.expectEqual(parameter_registry.RegisterResult.registered, engine.registerParameter(.{ .id = 2, .min_value = 0, .max_value = 100, .default_value = 0 }));
    try std.testing.expectEqual(parameter.SendResult.queued, engine.sendParameter(.{ .id = 1, .value = 1, .frame_offset = 3 }));
    for (0..parameter.max_events_per_block + 2) |i| {
        try std.testing.expectEqual(parameter.SendResult.queued, engine.sendParameter(.{ .id = 2, .value = @floatFromInt(i) }));
    }
    var samples: [4]f32 = undefined;
    var output = buffer.AudioBuffer.init(&samples, 2, 48_000);
    engine.process(&output);
    try std.testing.expectEqual(@as(usize, parameter.max_events_per_block - 1), probe.count);
    try std.testing.expectEqual(@as(u64, 1), engine.parameter_bus.telemetry().dropped);
    try std.testing.expect(engine.parameter_bus.receive() != null);
}

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
