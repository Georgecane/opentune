const std = @import("std");
const audio = @import("audio/audio.zig");

pub fn main() void {
    std.debug.print("OpenTune {s}\n", .{"0.1.0"});
    std.debug.print("Audio engine: {s}\n", .{"initialized"});
    std.debug.print("Sample rate: {d} Hz\n", .{audio.default_sample_rate});
}

test "OpenTune foundation" {
    try std.testing.expectEqual(@as(u32, 48_000), audio.default_sample_rate);
}
