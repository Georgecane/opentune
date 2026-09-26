const types = @import("../../core/types.zig");

pub const Scratch = struct {
    storage: []types.Sample,
    cursor: usize = 0,

    pub fn init(memory: []types.Sample) Scratch {
        return .{ .storage = memory };
    }

    pub fn reset(self: *Scratch) void {
        self.cursor = 0;
    }

    pub fn used(self: *const Scratch) usize {
        return self.cursor;
    }

    pub fn remaining(self: *const Scratch) usize {
        return self.storage.len - self.cursor;
    }

    pub fn take(self: *Scratch, count: usize) ?[]types.Sample {
        if (count > self.remaining()) return null;
        const start = self.cursor;
        self.cursor += count;
        return self.storage[start..self.cursor];
    }
};

test "scratch allocator can be reset and reused" {
    var memory = [_]types.Sample{0} ** 8;
    var scratch = Scratch.init(&memory);

    const first = scratch.take(3).?;
    first[0] = 1;
    first[2] = 3;

    try @import("std").testing.expectEqual(@as(usize, 3), scratch.used());
    try @import("std").testing.expectEqual(@as(usize, 5), scratch.remaining());
    try @import("std").testing.expect(scratch.take(6) == null);

    scratch.reset();
    try @import("std").testing.expectEqual(@as(usize, 0), scratch.used());

    const second = scratch.take(8).?;
    try @import("std").testing.expectEqual(@as(usize, 8), second.len);
}
