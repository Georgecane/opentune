const std = @import("std");
const types = @import("../core/types.zig");
const buffer = @import("../core/audio_buffer.zig");
const device = @import("device.zig");

pub const Processor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

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

    pub fn reset(self: *Processor, context: *const types.ProcessContext) void {
        self.vtable.reset(self.ptr, context);
    }
};

pub const ProcessFault = enum {
    none,
    invalid_sample_rate,
    invalid_channel_count,
    oversized_block,
};

pub const AudioEngine = struct {
    context: types.ProcessContext,
    processor: ?Processor = null,
    last_fault: ProcessFault = .none,

    pub fn init(sample_rate: types.SampleRate, block_size: types.FrameCount) AudioEngine {
        return .{
            .context = .{
                .sample_rate = sample_rate,
                .block_size = block_size,
                .transport_sample = 0,
            },
        };
    }

    pub fn setProcessor(self: *AudioEngine, processor: Processor) void {
        self.processor = processor;
    }

    pub fn reset(self: *AudioEngine) void {
        if (self.processor) |*processor| {
            processor.reset(&self.context);
        }
        self.context.transport_sample = 0;
        self.last_fault = .none;
    }

    /// Processes one bounded block. Invalid output metadata is handled fail-closed:
    /// clear the provided buffer, report a fault, and do not advance transport.
    /// This does not catch arbitrary processor panics or memory-safety faults.
    pub fn process(self: *AudioEngine, output: *buffer.AudioBuffer) void {
        self.last_fault = .none;

        if (output.sample_rate != self.context.sample_rate) {
            output.clear();
            self.last_fault = .invalid_sample_rate;
            return;
        }
        if (output.channels == 0) {
            output.clear();
            self.last_fault = .invalid_channel_count;
            return;
        }
        if (output.frames > self.context.block_size) {
            output.clear();
            self.last_fault = .oversized_block;
            return;
        }

        if (self.processor) |*processor| {
            processor.process(output, &self.context);
        } else {
            output.clear();
        }
        self.context.transport_sample += output.frames;
    }

    pub fn deviceCallback(
        user_data: ?*anyopaque,
        _: ?*const device.AudioBuffer,
        output: *device.AudioBuffer,
        context: *const types.ProcessContext,
    ) void {
        const engine: *AudioEngine = @ptrCast(@alignCast(user_data.?));
        engine.context.sample_rate = context.sample_rate;
        engine.context.block_size = context.block_size;
        engine.process(output);
    }
};

test "engine advances transport for a valid block" {
    var samples = [_]f32{0} ** 8;
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 4);
    engine.process(&out);
    try std.testing.expectEqual(@as(u64, 4), engine.context.transport_sample);
    try std.testing.expectEqual(ProcessFault.none, engine.last_fault);
}

test "engine clears invalid sample-rate output and reports fault" {
    var samples = [_]f32{1} ** 8;
    var out = buffer.AudioBuffer.init(&samples, 2, 44_100);
    var engine = AudioEngine.init(48_000, 4);
    engine.process(&out);
    try std.testing.expectEqual(ProcessFault.invalid_sample_rate, engine.last_fault);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}

test "engine clears oversized blocks and reports fault" {
    var samples = [_]f32{1} ** 12;
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 4);
    engine.process(&out);
    try std.testing.expectEqual(ProcessFault.oversized_block, engine.last_fault);
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
    for (out.samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}
