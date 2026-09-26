const types = @import("../core/types.zig");

pub const Message = struct {
    timestamp: u32,
    status: u8,
    data1: u8,
    data2: u8,
};

pub const Event = union(enum) {
    note_on: struct { channel: u8, note: u8, velocity: u8 },
    note_off: struct { channel: u8, note: u8, velocity: u8 },
    control_change: struct { channel: u8, controller: u8, value: u8 },
    raw: Message,
};

pub const EventBuffer = struct {
    events: []Event,
    len: usize = 0,

    pub fn clear(self: *EventBuffer) void {
        self.len = 0;
    }

    pub fn push(self: *EventBuffer, event: Event) bool {
        if (self.len >= self.events.len) return false;
        self.events[self.len] = event;
        self.len += 1;
        return true;
    }
};

pub const _sample = types.Sample;
