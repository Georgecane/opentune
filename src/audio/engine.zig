const std = @import("std");
const types = @import("../core/types.zig");
const audio = @import("audio.zig");
const device = @import("device.zig");

pub const ProcessingContext = types.ProcessContext;

pub const AudioProcessor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        process: *const fn (
            ptr: *anyopaque,
            buffer: *audio.AudioBuffer,
            context: *const ProcessingContext,
        ) void,
    };

    pub fn process(
        self: *AudioProcessor,
        buffer: *audio.AudioBuffer,
        context: *const ProcessingContext,
    ) void {
        self.vtable.process(self.ptr, buffer, context);
    }
};

pub const AudioEngine = struct {
    context: ProcessingContext,
    processor: ?AudioProcessor = null,

    pub fn init(sample_rate: u32, block_size: u32) AudioEngine {
        return .{
            .context = .{
                .sample_rate = sample_rate,
                .block_size = block_size,
                .transport_sample = 0,
            },
        };
    }

    pub fn setProcessor(self: *AudioEngine, processor: AudioProcessor) void {
        self.processor = processor;
    }

    pub fn process(self: *AudioEngine, buffer: *audio.AudioBuffer) void {
        std.debug.assert(buffer.sample_rate == self.context.sample_rate);
        std.debug.assert(buffer.frames <= self.context.block_size);

        if (self.processor) |*processor| {
            processor.process(buffer, &self.context);
        } else {
            buffer.clear();
        }

        self.context.transport_sample += buffer.frames;
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

test "engine advances transport without processor" {
    var samples = [_]audio.Sample{0} ** 8;
    var buffer = audio.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 4);

    engine.process(&buffer);

    try std.testing.expectEqual(@as(u64, 4), engine.context.transport_sample);
}
