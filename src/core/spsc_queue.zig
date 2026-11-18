const std = @import("std");
const builtin = @import("builtin");

/// A fixed-capacity single-producer/single-consumer ring queue.
///
/// Exactly one thread may call tryPush, and exactly one different thread may
/// call tryPop. The queue is not MPSC/MPMC and must not be copied after use.
/// Storage is embedded in the queue; operations never allocate or block.
///
/// Capacity must be a power of two so slot selection is a bounded mask.
/// Native-word counters keep atomic operations pointer-width on each target.
pub fn SpscQueue(comptime T: type, comptime capacity: usize) type {
    if (capacity < 2 or (capacity & (capacity - 1)) != 0) {
        @compileError("SpscQueue capacity must be a power of two greater than one");
    }
    if (capacity > std.math.maxInt(usize) / 2) {
        @compileError("SpscQueue capacity is too large for its wrapping counters");
    }

    return struct {
        const Self = @This();
        const Counter = std.atomic.Value(usize);
        const cache_line = std.atomic.cacheLineForCpu(builtin.target.cpu);
        const slot_mask = capacity - 1;

        slots: [capacity]T = undefined,

        // Each counter is written by only one side. Cache-line alignment
        // reduces false sharing between the producer and consumer counters.
        write_counter: Counter align(cache_line) = Counter.init(0),
        read_counter: Counter align(cache_line) = Counter.init(0),

        pub fn init() Self {
            return .{};
        }

        /// Attempts to enqueue one value. Returns false immediately when full.
        /// Call from the sole producer thread only.
        pub inline fn tryPush(self: *Self, value: T) bool {
            const write = self.write_counter.load(.monotonic);
            const read = self.read_counter.load(.acquire);

            if (write -% read >= capacity) return false;

            const slot_index: usize = @intCast(write & slot_mask);
            self.slots[slot_index] = value;

            // Publish the initialized slot to the consumer.
            self.write_counter.store(write +% 1, .release);
            return true;
        }

        /// Attempts to dequeue one value. Returns null immediately when empty.
        /// Call from the sole consumer thread only.
        pub inline fn tryPop(self: *Self) ?T {
            const read = self.read_counter.load(.monotonic);
            const write = self.write_counter.load(.acquire);

            if (read == write) return null;

            const slot_index: usize = @intCast(read & slot_mask);
            const value = self.slots[slot_index];

            // Release the slot so the producer may safely reuse it.
            self.read_counter.store(read +% 1, .release);
            return value;
        }
    };
}

test "SPSC queue is empty initially and preserves FIFO order" {
    var queue = SpscQueue(u32, 4).init();

    try std.testing.expect(queue.tryPop() == null);
    try std.testing.expect(queue.tryPush(10));
    try std.testing.expect(queue.tryPush(20));
    try std.testing.expect(queue.tryPush(30));

    try std.testing.expectEqual(@as(?u32, 10), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 20), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 30), queue.tryPop());
    try std.testing.expect(queue.tryPop() == null);
}

test "SPSC queue reports full without overwriting unread values" {
    var queue = SpscQueue(u32, 4).init();

    try std.testing.expect(queue.tryPush(1));
    try std.testing.expect(queue.tryPush(2));
    try std.testing.expect(queue.tryPush(3));
    try std.testing.expect(queue.tryPush(4));
    try std.testing.expect(!queue.tryPush(5));

    try std.testing.expectEqual(@as(?u32, 1), queue.tryPop());
    try std.testing.expect(queue.tryPush(5));

    try std.testing.expectEqual(@as(?u32, 2), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 3), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 4), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 5), queue.tryPop());
    try std.testing.expect(queue.tryPop() == null);
}

test "SPSC queue counters wrap without changing FIFO order" {
    var queue = SpscQueue(u32, 4).init();
    const start = std.math.maxInt(usize) - 1;
    queue.write_counter.store(start, .monotonic);
    queue.read_counter.store(start, .monotonic);

    try std.testing.expect(queue.tryPush(11));
    try std.testing.expect(queue.tryPush(22));
    try std.testing.expect(queue.tryPush(33));
    try std.testing.expect(queue.tryPush(44));
    try std.testing.expect(!queue.tryPush(55));

    try std.testing.expectEqual(@as(?u32, 11), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 22), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 33), queue.tryPop());
    try std.testing.expectEqual(@as(?u32, 44), queue.tryPop());
    try std.testing.expect(queue.tryPop() == null);
}

const StressState = struct {
    queue: SpscQueue(usize, 256) = .init(),
    failed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn stressProducer(state: *StressState, item_count: usize) void {
    for (0..item_count) |value| {
        if (state.cancelled.load(.acquire)) return;
        while (!state.queue.tryPush(value)) {
            if (state.cancelled.load(.acquire)) return;
            std.atomic.spinLoopHint();
        }
    }
}

fn stressConsumer(state: *StressState, item_count: usize) void {
    var expected: usize = 0;
    while (expected < item_count) {
        if (state.cancelled.load(.acquire)) return;
        if (state.queue.tryPop()) |value| {
            if (value != expected) {
                state.failed.store(true, .release);
            }
            expected += 1;
        } else {
            std.atomic.spinLoopHint();
        }
    }
}

test "SPSC queue preserves FIFO across concurrent producer and consumer" {
    if (builtin.single_threaded) return error.SkipZigTest;

    const item_count = 200_000;
    var state = StressState{};

    const consumer = try std.Thread.spawn(.{}, stressConsumer, .{ &state, item_count });
    const producer = std.Thread.spawn(.{}, stressProducer, .{ &state, item_count }) catch |err| {
        state.cancelled.store(true, .release);
        consumer.join();
        return err;
    };

    producer.join();
    consumer.join();

    try std.testing.expect(!state.failed.load(.acquire));
    try std.testing.expect(state.queue.tryPop() == null);
}
