const std = @import("std");
const queue_mod = @import("spsc_queue.zig");
const types = @import("types.zig");

pub const ParameterId = u32;
pub const max_events_per_block: usize = 64;
pub const queue_capacity: usize = 256;

/// A fixed-size parameter update. frame_offset is relative to the next
/// audio block observed by the consumer; it must be less than that block's size.
pub const ParameterEvent = struct {
    id: ParameterId,
    value: f32,
    frame_offset: types.FrameCount = 0,

    pub fn isValid(self: ParameterEvent, max_block_size: types.FrameCount) bool {
        return max_block_size > 0 and
            self.frame_offset < max_block_size and
            std.math.isFinite(self.value);
    }
};

pub const SendResult = enum {
    queued,
    invalid_event,
    queue_full,
};

pub const Telemetry = struct {
    accepted: u64,
    rejected_invalid: u64,
    rejected_full: u64,
    dispatched: u64,
    dropped: u64,
};

/// One control producer submits events; the audio callback is the sole consumer.
/// Do not reset, copy, or destroy this bus while either side is active.
pub const ParameterBus = struct {
    const Queue = queue_mod.SpscQueue(ParameterEvent, queue_capacity);

    queue: Queue = .init(),
    accepted: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    rejected_invalid: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    rejected_full: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    dispatched: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    dropped: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    /// Control-thread API. Never called by the audio callback.
    pub fn send(self: *ParameterBus, event: ParameterEvent, max_block_size: types.FrameCount) SendResult {
        if (!event.isValid(max_block_size)) {
            _ = self.rejected_invalid.fetchAdd(1, .monotonic);
            return .invalid_event;
        }
        if (!self.queue.tryPush(event)) {
            _ = self.rejected_full.fetchAdd(1, .monotonic);
            return .queue_full;
        }
        _ = self.accepted.fetchAdd(1, .monotonic);
        return .queued;
    }

    /// Audio-thread API. Returns immediately when no event is available.
    pub inline fn receive(self: *ParameterBus) ?ParameterEvent {
        return self.queue.tryPop();
    }

    pub inline fn markDispatched(self: *ParameterBus) void {
        _ = self.dispatched.fetchAdd(1, .monotonic);
    }

    pub inline fn markDropped(self: *ParameterBus) void {
        _ = self.dropped.fetchAdd(1, .monotonic);
    }

    /// Safe to call from a non-real-time thread. Values are independent atomic
    /// counters and are diagnostic snapshots, not a transactional invariant.
    pub fn telemetry(self: *const ParameterBus) Telemetry {
        return .{
            .accepted = self.accepted.load(.monotonic),
            .rejected_invalid = self.rejected_invalid.load(.monotonic),
            .rejected_full = self.rejected_full.load(.monotonic),
            .dispatched = self.dispatched.load(.monotonic),
            .dropped = self.dropped.load(.monotonic),
        };
    }
};

test "parameter event validates finite values and block-relative offsets" {
    try std.testing.expect((ParameterEvent{ .id = 1, .value = 0.5, .frame_offset = 3 }).isValid(4));
    try std.testing.expect(!(ParameterEvent{ .id = 1, .value = 0.5, .frame_offset = 4 }).isValid(4));
    try std.testing.expect(!(ParameterEvent{ .id = 1, .value = std.math.nan(f32) }).isValid(4));
    try std.testing.expect(!(ParameterEvent{ .id = 1, .value = std.math.inf(f32) }).isValid(4));
}

test "parameter bus rejects invalid input and reports queue saturation" {
    var bus = ParameterBus{};
    try std.testing.expectEqual(SendResult.invalid_event, bus.send(.{ .id = 1, .value = std.math.nan(f32) }, 128));
    for (0..queue_capacity) |i| {
        try std.testing.expectEqual(SendResult.queued, bus.send(.{ .id = 7, .value = @floatFromInt(i) }, 128));
    }
    try std.testing.expectEqual(SendResult.queue_full, bus.send(.{ .id = 7, .value = 1 }, 128));
    const stats = bus.telemetry();
    try std.testing.expectEqual(@as(u64, 256), stats.accepted);
    try std.testing.expectEqual(@as(u64, 1), stats.rejected_invalid);
    try std.testing.expectEqual(@as(u64, 1), stats.rejected_full);
}

test "parameter bus preserves event order" {
    var bus = ParameterBus{};
    try std.testing.expectEqual(SendResult.queued, bus.send(.{ .id = 3, .value = 0.25, .frame_offset = 2 }, 128));
    try std.testing.expectEqual(SendResult.queued, bus.send(.{ .id = 4, .value = 0.75 }, 128));
    try std.testing.expectEqual(@as(?ParameterEvent, .{ .id = 3, .value = 0.25, .frame_offset = 2 }), bus.receive());
    try std.testing.expectEqual(@as(?ParameterEvent, .{ .id = 4, .value = 0.75 }), bus.receive());
    try std.testing.expect(bus.receive() == null);
}
