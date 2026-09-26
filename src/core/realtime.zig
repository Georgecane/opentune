const std = @import("std");
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
    std.debug.assert(context.block_size > 0);
}

test "strict realtime policy forbids unsafe operations by contract" {
    const policy = RealtimePolicy.strict();
    try std.testing.expect(!policy.allow_allocation);
    try std.testing.expect(!policy.allow_blocking);
    try std.testing.expect(!policy.allow_io);
    try std.testing.expect(!policy.allow_logging);
}

test "realtime context accepts a bounded block" {
    const policy = RealtimePolicy{ .max_block_size = 256, .max_channels = 8 };
    const context = types.ProcessContext{
        .sample_rate = 48_000,
        .block_size = 128,
        .transport_sample = 0,
    };
    assertCompatible(policy, &context);
}
