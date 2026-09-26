const types = @import("../core/types.zig");

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
        process: *const fn (*anyopaque, *types.AudioBuffer, *const types.ProcessContext) void,
    };

    pub fn deinit(self: *PluginInstance) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn reset(self: *PluginInstance, context: *const types.ProcessContext) void {
        self.vtable.reset(self.ptr, context);
    }

    pub fn process(self: *PluginInstance, buffer: *types.AudioBuffer, context: *const types.ProcessContext) void {
        self.vtable.process(self.ptr, buffer, context);
    }
};
