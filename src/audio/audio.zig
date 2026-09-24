const std = @import("std");
const core_types = @import("../core/types.zig");
const buffer_module = @import("../core/audio_buffer.zig");

pub const default_sample_rate: u32 = 48_000;
pub const default_block_size: u32 = 128;

pub const Sample = core_types.Sample;
pub const AudioBuffer = buffer_module.AudioBuffer;

pub const Oscillator = struct {
    phase: f64 = 0.0,
    frequency: f64 = 440.0,
    sample_rate: f64 = @floatFromInt(default_sample_rate),

    pub fn process(self: *Oscillator, buffer: *AudioBuffer, amplitude: f32) void {
        if (buffer.channels == 0 or buffer.frames == 0) return;

        const two_pi = 2.0 * std.math.pi;
        const increment = two_pi * self.frequency / self.sample_rate;

        for (0..buffer.frames) |frame| {
            const value: f32 = @floatCast(@sin(self.phase) * @as(f64, amplitude));
            self.phase += increment;

            if (self.phase >= two_pi) {
                self.phase -= two_pi;
            }

            for (0..buffer.channels) |channel_index| {
                buffer.samples[frame * buffer.channels + channel_index] = value;
            }
        }
    }
};

test "oscillator renders finite samples" {
    var samples = [_]Sample{0} ** 16;
    var buffer = AudioBuffer.init(&samples, 2, 48_000);
    var oscillator = Oscillator{};
    oscillator.process(&buffer, 0.1);

    for (samples) |sample| {
        try std.testing.expect(std.math.isFinite(sample));
    }
}
