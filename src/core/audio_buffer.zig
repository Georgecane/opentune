const std = @import("std");
const types = @import("types.zig");

pub const AudioBuffer = struct {
    samples: []types.Sample,
    channels: types.ChannelCount,
    frames: types.FrameCount,
    sample_rate: types.SampleRate,
    layout: types.AudioLayout = .planar,

    pub fn init(samples: []types.Sample, channels: types.ChannelCount, sample_rate: types.SampleRate) AudioBuffer {
        const frames: types.FrameCount = if (channels == 0) 0 else @intCast(samples.len / @as(usize, channels));
        return .{ .samples = samples, .channels = channels, .frames = frames, .sample_rate = sample_rate };
    }

    /// Checks the storage invariants required by planar processing.
    /// Layout support is checked separately because interleaved buffers need
    /// a different channel-view API.
    pub fn hasValidStorage(self: *const AudioBuffer) bool {
        if (self.channels == 0 or self.sample_rate == 0 or self.frames == 0) return false;
        const channel_count: usize = self.channels;
        return self.samples.len % channel_count == 0 and
            self.samples.len / channel_count == self.frames;
    }

    pub fn clear(self: *AudioBuffer) void {
        @memset(self.samples, 0);
    }

    /// Returns a contiguous channel slice. Call only for valid planar buffers.
    pub fn channel(self: *AudioBuffer, index: types.ChannelCount) []types.Sample {
        std.debug.assert(self.layout == .planar);
        std.debug.assert(index < self.channels);
        const start = @as(usize, index) * self.frames;
        return self.samples[start .. start + self.frames];
    }

    /// Returns a channel window for a frame range in a planar buffer.
    /// The range is contiguous within the selected channel and does not allocate.
    pub fn channelRange(self: *AudioBuffer, index: types.ChannelCount, start_frame: types.FrameCount, frame_count: types.FrameCount) []types.Sample {
        std.debug.assert(self.layout == .planar);
        std.debug.assert(index < self.channels);
        std.debug.assert(start_frame <= self.frames);
        std.debug.assert(frame_count <= self.frames - start_frame);
        const channel_start = @as(usize, index) * self.frames;
        const start = channel_start + start_frame;
        return self.samples[start .. start + frame_count];
    }

    pub fn isCompatible(self: *const AudioBuffer, format: types.AudioFormat) bool {
        return self.sample_rate == format.sample_rate and
            self.channels == format.channels and
            self.layout == format.layout;
    }
};

test "audio buffer exposes planar channels" {
    var samples = [_]types.Sample{ 1, 2, 3, 4, 5, 6 };
    var buffer = AudioBuffer.init(&samples, 2, 48_000);
    try std.testing.expectEqualSlices(types.Sample, &[_]types.Sample{ 1, 2, 3 }, buffer.channel(0));
    try std.testing.expectEqualSlices(types.Sample, &[_]types.Sample{ 4, 5, 6 }, buffer.channel(1));
}

test "audio buffer exposes bounded planar channel ranges" {
    var samples = [_]types.Sample{ 0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17 };
    var audio = AudioBuffer.init(&samples, 2, 48_000);
    try std.testing.expectEqualSlices(types.Sample, &[_]types.Sample{ 2, 3, 4 }, audio.channelRange(0, 2, 3));
    try std.testing.expectEqualSlices(types.Sample, &[_]types.Sample{ 14, 15 }, audio.channelRange(1, 4, 2));
}

test "audio buffer detects malformed storage" {
    var samples = [_]types.Sample{ 1, 2, 3, 4, 5 };
    const buffer = AudioBuffer.init(&samples, 2, 48_000);
    try std.testing.expect(!buffer.hasValidStorage());
}