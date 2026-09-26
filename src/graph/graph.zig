const types = @import("../core/types.zig");
const buffer = @import("../core/audio_buffer.zig");
const node = @import("node.zig");

pub const AudioGraph = struct {
    nodes: []node.AudioNode = &.{},

    pub fn init(nodes: []node.AudioNode) AudioGraph { return .{ .nodes = nodes }; }

    pub fn reset(self: *AudioGraph, context: *const types.ProcessContext) void {
        for (self.nodes) |*current| current.reset(context);
    }

    pub fn process(self: *AudioGraph, input: ?*const buffer.AudioBuffer, output: *buffer.AudioBuffer, context: *const types.ProcessContext) void {
        if (self.nodes.len == 0) {
            output.clear();
            return;
        }
        var current_input = input;
        for (self.nodes) |*current| {
            current.process(current_input, output, context);
            current_input = output;
        }
    }
};
