const types = @import("../core/types.zig");

pub const Project = struct {
    sample_rate: types.SampleRate = 48_000,
    block_size: types.FrameCount = 128,
    track_count: u32 = 0,
    tempo: f64 = 120.0,
};
