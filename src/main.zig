const std = @import("std");
const ot = @import("opentune.zig");

const Generator = struct {
    oscillator: ot.dsp.oscillators.sine.Sine = .{},

    fn reset(ptr: *anyopaque, context: *const ot.core.types.ProcessContext) void {
        const self: *Generator = @ptrCast(@alignCast(ptr));
        self.oscillator.reset();
        self.oscillator.setSampleRate(context.sample_rate);
    }

    fn process(ptr: *anyopaque, output: *ot.core.audio_buffer.AudioBuffer, context: *const ot.core.types.ProcessContext) void {
        const self: *Generator = @ptrCast(@alignCast(ptr));
        self.oscillator.setSampleRate(context.sample_rate);
        self.oscillator.render(output, 0.08);
    }
};

const generator_vtable = ot.audio.engine.Processor.VTable{
    .process = Generator.process,
    .reset = Generator.reset,
};

pub fn main() void {
    std.debug.print("OpenTune 0.1.0
", .{});
    std.debug.print("Architecture: core -> dsp -> graph -> engine -> platform
", .{});
    std.debug.print("Default backend: {s}
", .{@tagName(ot.platform.backend.defaultKind())});

    var generator = Generator{};
    var processor = ot.audio.engine.Processor{
        .ptr = &generator,
        .vtable = &generator_vtable,
    };

    var engine = ot.audio.engine.AudioEngine.init(48_000, 128);
    engine.setProcessor(processor);

    var samples: [128 * 2]f32 = undefined;
    var buffer = ot.core.audio_buffer.AudioBuffer.init(&samples, 2, 48_000);
    engine.process(&buffer);

    std.debug.print("First sample: {d:.6}
", .{buffer.channel(0)[0]});
}

test "OpenTune public API" {
    try std.testing.expectEqual(@as(u32, 48_000), ot.audio.dsp_compat.default_sample_rate);
    try std.testing.expectEqual(@as(u32, 128), ot.audio.dsp_compat.default_block_size);
}
