const engine = @import("../audio/engine.zig");
const project = @import("../project/project.zig");

pub const App = struct {
    project_state: project.Project,
    audio_engine: engine.AudioEngine,

    pub fn init() App {
        const p = project.Project{};
        return .{
            .project_state = p,
            .audio_engine = engine.AudioEngine.init(p.sample_rate, p.block_size),
        };
    }
};
