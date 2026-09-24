const std = @import("std");
const types = @import("types.zig");

pub const AudioBuffer = struct {
    samples: []types.Sample,
    channels: types.ChannelCount,
    frames: types.FrameCount,
    sample_rate: types.SampleRate,

    pub fn init(
        samples: []types.Sample,
        channels: types.ChannelCount,
        sample_rate: types.SampleRate,
    ) AudioBuffer {
        const frames: types.FrameCount = if (channels == 0)
            0
        else
            @intCast(samples.len / @as(usize, channels));

        return .{
            .samples = samples,
            .channels = channels,
            .frames = frames,
            .sample_rate = sample_rate,
        };
    }

    pub fn clear(self: *AudioBuffer) void {
        @memset(self.samples, 0);
    }

    pub fn channel(self: *AudioBuffer, index: types.ChannelCount) []types.Sample {
        std.debug.assert(index < self.channels);
        const start = @as(usize, index) * self.frames;
        return self.samples[start .. start + self.frames];
    }

    pub fn isCompatible(self: *const AudioBuffer, format: types.AudioFormat) bool {
        return self.sample_rate == format.sample_rate and self.channels == format.channels;
    }
};

test "audio buffer exposes channels" {
    var samples = [_]types.Sample{ 1, 2, 3, 4, 5, 6 };
    var buffer = AudioBuffer.init(&samples, 2, 48_000);

    try std.testing.expectEqualSlices(
        types.Sample,
        &[_]types.Sample{ 1, 2, 3 },
        buffer.channel(0),
    );
    try std.testing.expectEqualSlices(
        types.Sample,
        &[_]types.Sample{ 4, 5, 6 },
        buffer.channel(1),
    );
}
