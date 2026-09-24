const types = @import("../core/types.zig");
const node = @import("node.zig");

pub const AudioGraph = struct {
    nodes: []node.AudioNode = &.{},

    pub fn init(nodes: []node.AudioNode) AudioGraph {
        return .{ .nodes = nodes };
    }

    pub fn reset(self: *AudioGraph, context: *const types.ProcessContext) void {
        for (self.nodes) |*current| {
            current.reset(context);
        }
    }

    pub fn process(
        self: *AudioGraph,
        input: ?*const @import("../core/audio_buffer.zig").AudioBuffer,
        output: *@import("../core/audio_buffer.zig").AudioBuffer,
        context: *const types.ProcessContext,
    ) void {
        if (self.nodes.len == 0) {
            output.clear();
            return;
        }

        self.nodes[0].process(input, output, context);
        for (self.nodes[1..]) |*current| {
            current.process(output, output, context);
        }
    }
};
