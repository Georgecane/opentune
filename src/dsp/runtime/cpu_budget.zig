const std = @import("std");
const types = @import("../../core/types.zig");

pub const CpuBudget = struct {
    sample_rate: types.SampleRate,
    block_size: types.FrameCount,

    pub fn init(sample_rate: types.SampleRate, block_size: types.FrameCount) CpuBudget {
        return .{ .sample_rate = sample_rate, .block_size = block_size };
    }

    pub fn blockNanoseconds(self: *const CpuBudget) u64 {
        if (self.sample_rate == 0) return 0;
        return (@as(u64, self.block_size) * std.time.ns_per_s) / self.sample_rate;
    }

    pub fn utilization(self: *const CpuBudget, elapsed_ns: u64) f64 {
        const budget = self.blockNanoseconds();
        if (budget == 0) return 0.0;
        return @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(budget));
    }
};

test "cpu budget at 48 kHz / 128 frames" {
    const budget = CpuBudget.init(48_000, 128);
    try std.testing.expectEqual(@as(u64, 2_666_666), budget.blockNanoseconds());
}
