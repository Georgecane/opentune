const std = @import("std");

pub fn add(comptime N: usize, a: @Vector(N, f32), b: @Vector(N, f32)) @Vector(N, f32) {
    return a + b;
}

pub fn mul(comptime N: usize, a: @Vector(N, f32), b: @Vector(N, f32)) @Vector(N, f32) {
    return a * b;
}

pub fn fill(comptime N: usize, value: f32) @Vector(N, f32) {
    return @splat(value);
}

pub fn multiplySlice(samples: []f32, gain: f32) void {
    const lanes = 4;
    var i: usize = 0;
    const gain_vec: @Vector(lanes, f32) = @splat(gain);

    while (i + lanes <= samples.len) : (i += lanes) {
        const values: @Vector(lanes, f32) = samples[i .. i + lanes][0..lanes].*;
        samples[i .. i + lanes][0..lanes].* = values * gain_vec;
    }

    while (i < samples.len) : (i += 1) {
        samples[i] *= gain;
    }
}

test "vector gain kernel" {
    var samples = [_]f32{ 1, 2, 3, 4, 5 };
    multiplySlice(&samples, 2);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 2, 4, 6, 8, 10 }, &samples);
}

test "vector operations" {
    const a: @Vector(4, f32) = @splat(2);
    const b: @Vector(4, f32) = @splat(3);
    const c = add(4, a, b);
    try std.testing.expectEqual(@as(f32, 5), c[0]);
    _ = std;
}
