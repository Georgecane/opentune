const std = @import("std");
const types = @import("../../core/types.zig");
const buffer = @import("../../core/audio_buffer.zig");

pub const Sine = struct {
    phase: f64 = 0,
    frequency: f64 = 440,
    sample_rate: f64 = 48_000,

    pub fn reset(self: *Sine) void { self.phase = 0; }
    pub fn setSampleRate(self: *Sine, sample_rate: types.SampleRate) void { self.sample_rate = @floatFromInt(sample_rate); }

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
