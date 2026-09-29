const types = @import("../core/types.zig");
const buffer = @import("../core/audio_buffer.zig");

pub const PluginKind = enum {
    native,
    clap,
    lv2,
};

pub const PluginDescriptor = struct {
    id: []const u8,
    name: []const u8,
    vendor: []const u8,
    version: []const u8,
    kind: PluginKind,
};

pub const PluginInstance = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*anyopaque) void,
        reset: *const fn (*anyopaque, *const types.ProcessContext) void,
        process: *const fn (*anyopaque, *buffer.AudioBuffer, *const types.ProcessContext) void,
    };

    pub fn deinit(self: *PluginInstance) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn reset(self: *PluginInstance, context: *const types.ProcessContext) void {
        self.vtable.reset(self.ptr, context);
    }

    pub fn process(
        self: *PluginInstance,
        audio: *buffer.AudioBuffer,
        context: *const types.ProcessContext,
    ) void {
        self.vtable.process(self.ptr, audio, context);
    }
};
