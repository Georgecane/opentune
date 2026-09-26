pub const runtime = struct {
    pub const cpu_budget = @import("runtime/cpu_budget.zig");
    pub const scratch = @import("runtime/scratch.zig");
};

pub const simd = struct {
    pub const vector = @import("simd/vector.zig");
};

pub const filters = struct {
    pub const biquad = @import("filters/biquad.zig");
};

pub const oscillators = struct {
    pub const sine = @import("oscillators/sine.zig");
};
