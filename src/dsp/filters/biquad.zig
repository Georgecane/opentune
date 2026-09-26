const std = @import("std");
const types = @import("../../core/types.zig");
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

    pub fn init(states: []State) Biquad { return .{ .states = states }; }
    pub fn setCoefficients(self: *Biquad, coefficients: Coefficients) void { self.coefficients = coefficients; }
    pub fn reset(self: *Biquad) void { for (self.states) |*state| state.* = .{}; }

    pub fn process(self: *Biquad, audio: *buffer.AudioBuffer) void {
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

test "lowpass coefficients are finite" {
    const c = lowpass(48_000, 1_000, 0.707);
    try std.testing.expect(std.math.isFinite(c.b0));
    try std.testing.expect(std.math.isFinite(c.a2));
    _ = types.Sample;
}
