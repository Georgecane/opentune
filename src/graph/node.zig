const types = @import("../core/types.zig");
const audio_buffer = @import("../core/audio_buffer.zig");

pub const AudioNode = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        reset: *const fn (ptr: *anyopaque, context: *const types.ProcessContext) void,
        process: *const fn (
            ptr: *anyopaque,
            input: ?*const audio_buffer.AudioBuffer,
            output: *audio_buffer.AudioBuffer,
            context: *const types.ProcessContext,
        ) void,
    };

    pub fn deinit(self: *AudioNode) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn reset(
        self: *AudioNode,
        context: *const types.ProcessContext,
    ) void {
        self.vtable.reset(self.ptr, context);
    }

    pub fn process(
        self: *AudioNode,
        input: ?*const audio_buffer.AudioBuffer,
        output: *audio_buffer.AudioBuffer,
        context: *const types.ProcessContext,
    ) void {
        self.vtable.process(self.ptr, input, output, context);
    }
};
