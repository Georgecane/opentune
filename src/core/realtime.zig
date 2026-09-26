const types = @import("types.zig");

pub const RealtimePolicy = struct {
    max_block_size: types.FrameCount = 128,
    max_channels: types.ChannelCount = 2,
    allow_allocation: bool = false,
    allow_blocking: bool = false,
    allow_io: bool = false,
    allow_logging: bool = false,

    pub fn strict() RealtimePolicy {
        return .{};
    }
};

pub const RealtimeContext = struct {
    process: types.ProcessContext,
    policy: RealtimePolicy,
};

pub fn assertCompatible(policy: RealtimePolicy, context: *const types.ProcessContext) void {
    std.debug.assert(context.block_size <= policy.max_block_size);
    _ = policy;
}

const std = @import("std");

test "strict realtime policy forbids unsafe operations by contract" {
    const policy = RealtimePolicy.strict();
    try std.testing.expect(!policy.allow_allocation);
    try std.testing.expect(!policy.allow_blocking);
    try std.testing.expect(!policy.allow_io);
}
