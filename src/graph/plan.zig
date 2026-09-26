const node = @import("node.zig");

pub const ExecutionPlan = struct {
    order: []node.AudioNode,

    pub fn init(order: []node.AudioNode) ExecutionPlan {
        return .{ .order = order };
    }

    pub fn reset(self: *ExecutionPlan, context: anytype) void {
        for (self.order) |*item| item.reset(context);
    }

    pub fn process(self: *ExecutionPlan, input: anytype, output: anytype, context: anytype) void {
        var current_input = input;
        for (self.order) |*item| {
            item.process(current_input, output, context);
            current_input = output;
        }
    }
};
