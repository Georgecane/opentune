const std = @import("std");
const ot = @import("../src/opentune.zig");

test "core audio format compatibility" {
    const format = ot.core.types.AudioFormat.init(48_000, 2);
    var samples = [_]f32{0} ** 16;
    const audio = ot.core.audio_buffer.AudioBuffer.init(&samples, 2, 48_000);
    try std.testing.expect(audio.isCompatible(format));
    try std.testing.expect(!audio.isCompatible(.{ .sample_rate = 44_100, .channels = 2 }));
    try std.testing.expect(!audio.isCompatible(.{ .sample_rate = 48_000, .channels = 1 }));
}

test "audio buffer clear removes all samples" {
    var samples = [_]f32{1, -2, 3, 4, -5, 6};
    var audio = ot.core.audio_buffer.AudioBuffer.init(&samples, 2, 48_000);
    audio.clear();
    for (audio.samples) |sample| {
        try std.testing.expectEqual(@as(f32, 0), sample);
    }
}

test "cpu budget reports expected block duration" {
    const budget = ot.dsp.runtime.cpu_budget.CpuBudget.init(48_000, 128);
    try std.testing.expectEqual(@as(u64, 2_666_666), budget.blockNanoseconds());
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), budget.utilization(2_666_666), 0.000001);
    try std.testing.expect(budget.utilization(5_333_332) > 1.9);
}

test "scratch pool never exceeds capacity" {
    var storage = [_]f32{0} ** 4;
    var scratch = ot.dsp.runtime.scratch.Scratch.init(&storage);
    try std.testing.expect(scratch.take(3) != null);
    try std.testing.expect(scratch.take(2) == null);
    try std.testing.expectEqual(@as(usize, 3), scratch.used());
    scratch.reset();
    try std.testing.expectEqual(@as(usize, 0), scratch.used());
}

test "simd multiply matches scalar expectation" {
    var samples = [_]f32{ 0.5, -1, 2, 3.5, 8, -4, 0, 1 };
    ot.dsp.simd.vector.multiplySlice(&samples, 0.25);
    const expected = [_]f32{ 0.125, -0.25, 0.5, 0.875, 2, -1, 0, 0.25 };
    try std.testing.expectEqualSlices(f32, &expected, &samples);
}

test "sine oscillator starts at zero and writes every channel" {
    var samples = [_]f32{0} ** 16;
    var audio = ot.core.audio_buffer.AudioBuffer.init(&samples, 2, 48_000);
    var osc = ot.dsp.oscillators.sine.Sine{ .frequency = 1_000 };
    osc.render(&audio, 0.5);

    try std.testing.expectApproxEqAbs(@as(f32, 0), audio.channel(0)[0], 0.000001);
    try std.testing.expectEqualSlices(f32, audio.channel(0), audio.channel(1));
    try std.testing.expect(audio.channel(0)[1] > 0);
}

test "sine oscillator reset is deterministic" {
    var first = [_]f32{0} ** 32;
    var second = [_]f32{0} ** 32;
    var a = ot.core.audio_buffer.AudioBuffer.init(&first, 1, 48_000);
    var b = ot.core.audio_buffer.AudioBuffer.init(&second, 1, 48_000);
    var osc = ot.dsp.oscillators.sine.Sine{ .frequency = 440 };
    osc.render(&a, 1);
    osc.reset();
    osc.render(&b, 1);
    try std.testing.expectEqualSlices(f32, a.samples, b.samples);
}

test "graph executes nodes in declared order" {
    const Context = ot.core.types.ProcessContext;
    const Buffer = ot.core.audio_buffer.AudioBuffer;

    const NodeState = struct {
        value: f32,
    };

    const Node = struct {
        state: *NodeState,

        fn deinit(_: *anyopaque) void {}

        fn reset(ptr: *anyopaque, _: *const Context) void {
            const self: *Node = @ptrCast(@alignCast(ptr));
            self.state.value = 0;
        }

        fn process(
            ptr: *anyopaque,
            input: ?*const Buffer,
            output: *Buffer,
            _: *const Context,
        ) void {
            const self: *Node = @ptrCast(@alignCast(ptr));
            const value = if (input) |in| in.channel(0)[0] else 0;
            self.state.value = value + 1;
            output.clear();
            output.channel(0)[0] = self.state.value;
        }
    };

    var a_state = NodeState{ .value = 0 };
    var b_state = NodeState{ .value = 0 };
    var a = Node{ .state = &a_state };
    var b = Node{ .state = &b_state };
    const vt = ot.graph.node.AudioNode.VTable{
        .deinit = Node.deinit,
        .reset = Node.reset,
        .process = Node.process,
    };
    var nodes = [_]ot.graph.node.AudioNode{
        .{ .ptr = &a, .vtable = &vt },
        .{ .ptr = &b, .vtable = &vt },
    };
    var graph = ot.graph.graph.AudioGraph.init(&nodes);
    var samples = [_]f32{0};
    var output = Buffer.init(&samples, 1, 48_000);
    const context = Context{
        .sample_rate = 48_000,
        .block_size = 1,
        .transport_sample = 0,
    };
    graph.process(null, &output, &context);

    try std.testing.expectEqual(@as(f32, 1), a_state.value);
    try std.testing.expectEqual(@as(f32, 2), b_state.value);
    try std.testing.expectEqual(@as(f32, 2), output.channel(0)[0]);
}

test "midi event buffer is bounded and reusable" {
    var events = [_]ot.midi.Event{
        .{ .raw = .{ .timestamp = 0, .status = 0x90, .data1 = 60, .data2 = 100 } },
        .{ .raw = .{ .timestamp = 1, .status = 0x80, .data1 = 60, .data2 = 0 } },
    };
    var buffer = ot.midi.EventBuffer{ .events = &events };
    try std.testing.expect(buffer.push(.{ .note_on = .{ .channel = 0, .note = 60, .velocity = 100 } }));
    try std.testing.expect(buffer.push(.{ .note_off = .{ .channel = 0, .note = 60, .velocity = 0 } }));
    try std.testing.expect(!buffer.push(.{ .control_change = .{ .channel = 0, .controller = 1, .value = 2 } }));
    try std.testing.expectEqual(@as(usize, 2), buffer.len);
    buffer.clear();
    try std.testing.expectEqual(@as(usize, 0), buffer.len);
}

test "project defaults are deterministic" {
    const project = ot.project.project.Project{};
    try std.testing.expectEqual(@as(u32, 48_000), project.sample_rate);
    try std.testing.expectEqual(@as(u32, 128), project.block_size);
    try std.testing.expectEqual(@as(u32, 0), project.track_count);
    try std.testing.expectApproxEqAbs(@as(f64, 120.0), project.tempo, 0.000001);
}

test "audio engine advances exactly by processed frames" {
    var samples = [_]f32{0} ** 12;
    var output = ot.core.audio_buffer.AudioBuffer.init(&samples, 2, 48_000);
    var engine = ot.audio.engine.AudioEngine.init(48_000, 128);
    engine.process(&output);
    try std.testing.expectEqual(@as(u64, 6), engine.context.transport_sample);
    engine.reset();
    try std.testing.expectEqual(@as(u64, 0), engine.context.transport_sample);
}
