const std = @import("std");
const ot = @import("opentune.zig");

const Generator = struct {
    oscillator: ot.audio.dsp.Oscillator = .{},

    fn deinit(_: *anyopaque) void {}

    fn reset(ptr: *anyopaque, context: *const ot.core.types.ProcessContext) void {
        const self: *Generator = @ptrCast(@alignCast(ptr));
        self.oscillator.phase = 0.0;
        self.oscillator.sample_rate = @floatFromInt(context.sample_rate);
    }

    fn process(
        ptr: *anyopaque,
        _: ?*const ot.core.audio_buffer.AudioBuffer,
        output: *ot.core.audio_buffer.AudioBuffer,
        context: *const ot.core.types.ProcessContext,
    ) void {
        const self: *Generator = @ptrCast(@alignCast(ptr));
        self.oscillator.sample_rate = @floatFromInt(context.sample_rate);
        self.oscillator.process(output, 0.08);
    }
};

const generator_vtable = ot.graph.node.AudioNode.VTable{
    .deinit = Generator.deinit,
    .reset = Generator.reset,
    .process = Generator.process,
};

fn graphProcess(
    ptr: *anyopaque,
    buffer: *ot.core.audio_buffer.AudioBuffer,
    context: *const ot.core.types.ProcessContext,
) void {
    const graph: *ot.graph.graph.AudioGraph = @ptrCast(@alignCast(ptr));
    graph.process(null, buffer, context);
}

pub fn main() void {
    std.debug.print("OpenTune {s}\n", .{"0.1.0"});
    std.debug.print("API architecture: platform-neutral\n", .{});
    std.debug.print("Default backend: {s}\n", .{@tagName(ot.platform.backend.defaultKind())});

    var generator = Generator{};
    var generator_node = ot.graph.node.AudioNode{
        .ptr = &generator,
        .vtable = &generator_vtable,
    };

    var nodes = [_]ot.graph.node.AudioNode{generator_node};
    var graph = ot.graph.graph.AudioGraph.init(&nodes);

    var engine = ot.audio.engine.AudioEngine.init(
        ot.audio.dsp.default_sample_rate,
        ot.audio.dsp.default_block_size,
    );

    var samples: [ot.audio.dsp.default_block_size * 2]ot.audio.dsp.Sample = undefined;
    var buffer = ot.core.audio_buffer.AudioBuffer.init(
        &samples,
        2,
        ot.audio.dsp.default_sample_rate,
    );

    engine.setProcessor(.{
        .ptr = &graph,
        .vtable = &.{
            .process = graphProcess,
        },
    });

    engine.process(&buffer);
    std.debug.print("First sample: {d:.6}\n", .{buffer.samples[0]});

    generator_node.deinit();
}

test "OpenTune public API foundation" {
    try std.testing.expectEqual(@as(u32, 48_000), ot.audio.dsp.default_sample_rate);
    try std.testing.expectEqual(@as(u32, 128), ot.audio.dsp.default_block_size);
}
