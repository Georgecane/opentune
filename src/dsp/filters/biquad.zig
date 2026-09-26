const std = @import("std");
const buffer = @import("../../core/audio_buffer.zig");

pub const Coefficients = struct {
    b0: f32 = 1,
    b1: f32 = 0,
    b2: f32 = 0,
    a1: f32 = 0,
    a2: f32 = 0,
};

pub const State = struct { z1: f32 = 0, z2: f32 = 0 };

pub const Biquad = struct {
    coefficients: Coefficients = .{},
    states: []State = &.{},

    pub fn init(states: []State) Biquad {
        return .{ .states = states };
    }

    pub fn setCoefficients(self: *Biquad, coefficients: Coefficients) void {
        self.coefficients = coefficients;
    }

    pub fn reset(self: *Biquad) void {
        for (self.states) |*state| state.* = .{};
    }

    pub fn process(self: *Biquad, audio: *buffer.AudioBuffer) void {
        std.debug.assert(self.states.len >= audio.channels);
        for (0..audio.channels) |channel| {
            var state = &self.states[channel];
            const samples = audio.channel(@intCast(channel));
            for (samples) |*sample| {
                const input = sample.*;
                const output = self.coefficients.b0 * input + state.z1;
                state.z1 = self.coefficients.b1 * input - self.coefficients.a1 * output + state.z2;
                state.z2 = self.coefficients.b2 * input - self.coefficients.a2 * output;
                sample.* = output;
            }
        }
    }
};

pub fn lowpass(sample_rate: f32, frequency: f32, q: f32) Coefficients {
    std.debug.assert(sample_rate > 0);
    std.debug.assert(frequency > 0 and frequency < sample_rate * 0.5);
    std.debug.assert(q > 0);

    const w0 = 2.0 * std.math.pi * frequency / sample_rate;
    const alpha = @sin(w0) / (2.0 * q);
    const cos_w0 = @cos(w0);
    const b0 = (1.0 - cos_w0) / 2.0;
    const b1 = 1.0 - cos_w0;
    const a0 = 1.0 + alpha;
    const a1 = -2.0 * cos_w0;
    const a2 = 1.0 - alpha;
    return .{ .b0 = b0 / a0, .b1 = b1 / a0, .b2 = b0 / a0, .a1 = a1 / a0, .a2 = a2 / a0 };
}

fn expectFinite(c: Coefficients) !void {
    try std.testing.expect(std.math.isFinite(c.b0));
    try std.testing.expect(std.math.isFinite(c.b1));
    try std.testing.expect(std.math.isFinite(c.b2));
    try std.testing.expect(std.math.isFinite(c.a1));
    try std.testing.expect(std.math.isFinite(c.a2));
}

test "lowpass has unity DC gain" {
    const c = lowpass(48_000, 1_000, 0.707);
    try expectFinite(c);

    const numerator = c.b0 + c.b1 + c.b2;
    const denominator = 1.0 + c.a1 + c.a2;
    const dc_gain = numerator / denominator;

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dc_gain, 0.00001);
}

test "lowpass impulse response matches the recurrence" {
    const c = lowpass(48_000, 1_000, 0.707);
    var actual_samples = [_]f32{0} ** 64;
    var expected_samples = [_]f32{0} ** 64;

    actual_samples[0] = 1;
    var audio = buffer.AudioBuffer.init(&actual_samples, 1, 48_000);
    var states = [_]State{.{}};
    var filter = Biquad.init(&states);
    filter.setCoefficients(c);
    filter.process(&audio);

    var z1: f32 = 0;
    var z2: f32 = 0;
    for (0..expected_samples.len) |i| {
        const input: f32 = if (i == 0) 1 else 0;
        const output = c.b0 * input + z1;
        z1 = c.b1 * input - c.a1 * output + z2;
        z2 = c.b2 * input - c.a2 * output;
        expected_samples[i] = output;
    }

    for (actual_samples, expected_samples) |actual, expected| {
        try std.testing.expectApproxEqAbs(expected, actual, 0.0000001);
        try std.testing.expect(std.math.isFinite(actual));
    }
}

test "lowpass step response converges to its DC gain" {
    const c = lowpass(48_000, 1_000, 0.707);
    const expected_gain = (c.b0 + c.b1 + c.b2) / (1.0 + c.a1 + c.a2);

    var samples = [_]f32{1} ** 4096;
    var audio = buffer.AudioBuffer.init(&samples, 1, 48_000);
    var states = [_]State{.{}};
    var filter = Biquad.init(&states);
    filter.setCoefficients(c);
    filter.process(&audio);

    const final = audio.channel(0)[audio.frames - 1];
    try std.testing.expectApproxEqAbs(expected_gain, final, 0.0001);
    for (audio.channel(0)) |sample| {
        try std.testing.expect(std.math.isFinite(sample));
    }
}

test "lowpass state is continuous across blocks" {
    const c = lowpass(48_000, 1_000, 0.707);

    var whole = [_]f32{1} ** 256;
    var split = [_]f32{1} ** 256;

    var whole_audio = buffer.AudioBuffer.init(&whole, 1, 48_000);
    var split_first_audio = buffer.AudioBuffer.init(split[0..128], 1, 48_000);
    var split_second_audio = buffer.AudioBuffer.init(split[128..], 1, 48_000);

    var whole_states = [_]State{.{}};
    var split_states = [_]State{.{}};
    var whole_filter = Biquad.init(&whole_states);
    var split_filter = Biquad.init(&split_states);
    whole_filter.setCoefficients(c);
    split_filter.setCoefficients(c);

    whole_filter.process(&whole_audio);
    split_filter.process(&split_first_audio);
    split_filter.process(&split_second_audio);

    try std.testing.expectEqualSlices(f32, whole_audio.samples, split);
}

test "biquad reset restores the initial response" {
    const c = lowpass(48_000, 1_000, 0.707);
    var first = [_]f32{1} ** 128;
    var second = [_]f32{1} ** 128;

    var a = buffer.AudioBuffer.init(&first, 1, 48_000);
    var b = buffer.AudioBuffer.init(&second, 1, 48_000);
    var states = [_]State{.{}};
    var filter = Biquad.init(&states);
    filter.setCoefficients(c);

    filter.process(&a);
    filter.reset();
    filter.process(&b);

    try std.testing.expectEqualSlices(f32, first, second);
}
