pub const core = struct {
    pub const types = @import("core/types.zig");
    pub const audio_buffer = @import("core/audio_buffer.zig");
};

pub const audio = struct {
    pub const device = @import("audio/device.zig");
    pub const engine = @import("audio/engine.zig");
    pub const dsp = @import("audio/audio.zig");
};

pub const graph = struct {
    pub const node = @import("graph/node.zig");
    pub const graph = @import("graph/graph.zig");
};

pub const platform = struct {
    pub const backend = @import("platform/backend.zig");
};
