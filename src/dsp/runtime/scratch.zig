const types = @import("../../core/types.zig");

pub const Scratch = struct {
    memory: []types.Sample,

    pub fn init(memory: []types.Sample) Scratch {
        return .{ .memory = memory };
    }

    pub fn reset(self: *Scratch) void {
        _ = self;
    }

    pub fn take(self: *Scratch, count: usize) ?[]types.Sample {
        if (count > self.memory.len) return null;
        const result = self.memory[0..count];
        self.memory = self.memory[count..];
        return result;
    }
};
