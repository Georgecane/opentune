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

pub const AudioEngine = struct {
    context: types.ProcessContext,
    processor: ?Processor = null,

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
    }

    pub fn process(self: *AudioEngine, output: *buffer.AudioBuffer) void {
        std.debug.assert(output.sample_rate == self.context.sample_rate);
        std.debug.assert(output.frames <= self.context.block_size);
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

test "engine advances transport" {
    var samples = [_]f32{0} ** 8;
    var out = buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 4);
    engine.process(&out);
    try std.testing.expectEqual(@as(u64, 4), engine.context.transport_sample);
}
