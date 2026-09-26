pub const core = struct {
    pub const types = @import("core/types.zig");
    pub const audio_buffer = @import("core/audio_buffer.zig");
    pub const realtime = @import("core/realtime.zig");
};

pub const dsp = @import("dsp/dsp.zig");

pub const audio = struct {
    pub const device = @import("audio/device.zig");
    pub const engine = @import("audio/engine.zig");
    pub const dsp_compat = @import("audio/audio.zig");
};

pub const graph = struct {
    pub const node = @import("graph/node.zig");
    pub const graph = @import("graph/graph.zig");
    pub const plan = @import("graph/plan.zig");
};

pub const platform = struct {
    pub const backend = @import("platform/backend.zig");
};

pub const plugin = @import("plugin/plugin_api.zig");
pub const midi = @import("midi/midi_api.zig");
pub const project = @import("project/project_api.zig");
pub const ui = @import("ui/ui.zig");
pub const app = @import("app/app.zig");
