pub const default_sample_rate: u32 = 48_000;
pub const default_block_size: u32 = 128;
pub const Sample = @import("../core/types.zig").Sample;
pub const AudioBuffer = @import("../core/audio_buffer.zig").AudioBuffer;
pub const Oscillator = @import("../dsp/oscillators/sine.zig").Sine;
