const std = @import("std");
const audio = @import("audio/audio.zig");

pub fn main() !void {
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.print("OpenTune {s}\n", .{"0.1.0"});
    try stdout.interface.print("Audio engine: {s}\n", .{"initialized"});
    try stdout.interface.print("Sample rate: {d} Hz\n", .{audio.default_sample_rate});
}

test "OpenTune foundation" {
    try std.testing.expectEqual(@as(u32, 48_000), audio.default_sample_rate);
}
