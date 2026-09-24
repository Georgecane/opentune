pub const default_sample_rate: u32 = 48_000;
pub const default_block_size: u32 = 128;

pub const Sample = f32;

pub const AudioBuffer = struct {
    samples: []Sample,
    channels: u32,
    frames: u32,
    sample_rate: u32,

    pub fn init(samples: []Sample, channels: u32, sample_rate: u32) AudioBuffer {
        const frames = if (channels == 0) 0 else @as(u32, @intCast(samples.len / channels));
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

    pub fn channel(self: *AudioBuffer, index: u32) []Sample {
        const start = @as(usize, index) * self.frames;
        return self.samples[start .. start + self.frames];
    }
};

pub const Oscillator = struct {
    phase: f64 = 0.0,
    frequency: f64 = 440.0,
    sample_rate: f64 = @floatFromInt(default_sample_rate),

    pub fn process(self: *Oscillator, buffer: *AudioBuffer, amplitude: f32) void {
        const channels = buffer.channels;
        if (channels == 0) return;

        const increment = 2.0 * std.math.pi * self.frequency / self.sample_rate;
        for (0..buffer.frames) |frame| {
            const value: f32 = @floatCast(@sin(self.phase) * @as(f64, amplitude));
            self.phase += increment;
            if (self.phase >= 2.0 * std.math.pi) self.phase -= 2.0 * std.math.pi;

            for (0..channels) |channel_index| {
                buffer.samples[frame * channels + channel_index] = value;
            }
        }
    }
};

test "audio buffer clears samples" {
    var samples = [_]Sample{ 1, -2, 3, -4 };
    var buffer = AudioBuffer.init(&samples, 2, 48_000);
    buffer.clear();
    try @import("std").testing.expectEqualSlices(Sample, &[_]Sample{ 0, 0, 0, 0 }, samples[0..]);
}

test "oscillator renders finite samples" {
    var samples = [_]Sample{0} ** 16;
    var buffer = AudioBuffer.init(&samples, 2, 48_000);
    var oscillator = Oscillator{};
    oscillator.process(&buffer, 0.1);
    for (samples) |sample| {
        try @import("std").testing.expect(std.math.isFinite(sample));
    }
}
