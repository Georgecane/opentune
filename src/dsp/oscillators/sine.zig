const std = @import("std");
const types = @import("../../core/types.zig");
const buffer = @import("../../core/audio_buffer.zig");

pub const Sine = struct {
    phase: f64 = 0,
    frequency: f64 = 440,
    sample_rate: f64 = 48_000,

    pub fn reset(self: *Sine) void {
        self.phase = 0;
    }

    pub fn setSampleRate(self: *Sine, sample_rate: types.SampleRate) void {
        self.sample_rate = @floatFromInt(sample_rate);
    }

    pub fn render(self: *Sine, audio: *buffer.AudioBuffer, amplitude: f32) void {
        if (self.sample_rate <= 0 or audio.channels == 0) return;
        const increment = 2.0 * std.math.pi * self.frequency / self.sample_rate;
        for (0..audio.frames) |frame| {
            const value: f32 = @floatCast(@sin(self.phase) * @as(f64, amplitude));
            self.phase += increment;
            if (self.phase >= 2.0 * std.math.pi) self.phase -= 2.0 * std.math.pi;
            for (0..audio.channels) |channel| audio.channel(@intCast(channel))[frame] = value;
        }
    }
};

test "sine produces the mathematically expected waveform" {
    const sample_rate: f64 = 48_000;
    const frequency: f64 = 1_000;
    const amplitude: f32 = 0.5;

    var samples = [_]f32{0} ** 480;
    var audio = buffer.AudioBuffer.init(&samples, 1, 48_000);
    var osc = Sine{ .frequency = frequency, .sample_rate = sample_rate };
    osc.render(&audio, amplitude);

    for (audio.channel(0), 0..) |actual, n| {
        const phase = 2.0 * std.math.pi * frequency * @as(f64, @floatFromInt(n)) / sample_rate;
        const expected: f32 = @floatCast(@sin(phase) * @as(f64, amplitude));
        try std.testing.expectApproxEqAbs(expected, actual, 0.000001);
        try std.testing.expect(@abs(actual) <= amplitude + 0.000001);
    }
}

test "sine frequency remains accurate across multiple blocks" {
    const sample_rate: f64 = 48_000;
    const frequency: f64 = 440;
    const block_size = 128;

    var samples = [_]f32{0} ** (block_size * 4);
    var audio = buffer.AudioBuffer.init(&samples, 1, 48_000);
    var osc = Sine{ .frequency = frequency, .sample_rate = sample_rate };

    for (0..4) |block| {
        const start = block * block_size;
        osc.render(&audio.channel(0)[start .. start + block_size].*, 1);
    }

    for (audio.channel(0), 0..) |actual, n| {
        const phase = 2.0 * std.math.pi * frequency * @as(f64, @floatFromInt(n)) / sample_rate;
        const expected: f32 = @floatCast(@sin(phase));
        try std.testing.expectApproxEqAbs(expected, actual, 0.000002);
    }
}

test "sine reset is bitwise deterministic for the same render" {
    var first = [_]f32{0} ** 256;
    var second = [_]f32{0} ** 256;
    var a = buffer.AudioBuffer.init(&first, 1, 48_000);
    var b = buffer.AudioBuffer.init(&second, 1, 48_000);
    var osc = Sine{ .frequency = 440 };

    osc.render(&a, 1);
    osc.reset();
    osc.render(&b, 1);

    try std.testing.expectEqualSlices(f32, a.samples, b.samples);
}

test "sine writes identical values to every channel" {
    var samples = [_]f32{0} ** 96;
    var audio = buffer.AudioBuffer.init(&samples, 3, 48_000);
    var osc = Sine{ .frequency = 440 };
    osc.render(&audio, 0.75);

    try std.testing.expectEqualSlices(f32, audio.channel(0), audio.channel(1));
    try std.testing.expectEqualSlices(f32, audio.channel(1), audio.channel(2));
}
