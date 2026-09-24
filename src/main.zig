const std = @import("std");
const audio = @import("audio/audio.zig");
const engine_module = @import("audio/engine.zig");

pub fn main() void {
    std.debug.print("OpenTune {s}\n", .{"0.1.0"});
    std.debug.print("Zig target: {s}\n", .{"0.16.0"});
    std.debug.print("Audio engine: {s}\n", .{"initialized"});
    std.debug.print("Sample rate: {d} Hz\n", .{audio.default_sample_rate});
    std.debug.print("Block size: {d} frames\n", .{audio.default_block_size});

    var engine = engine_module.AudioEngine.init(
        audio.default_sample_rate,
        audio.default_block_size,
    );

    var samples: [audio.default_block_size * 2]audio.Sample = undefined;
    var buffer = audio.AudioBuffer.init(
        &samples,
        2,
        audio.default_sample_rate,
    );
    var oscillator = audio.Oscillator{};

    engine.process(&buffer, &oscillator);

    std.debug.print("First sample: {d:.6}\n", .{buffer.samples[0]});
}

test "OpenTune foundation" {
    try std.testing.expectEqual(@as(u32, 48_000), audio.default_sample_rate);
    try std.testing.expectEqual(@as(u32, 128), audio.default_block_size);
}
