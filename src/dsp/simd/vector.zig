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

test "vector gain kernel matches scalar reference for every tail length" {
    const lengths = [_]usize{ 0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 31, 32, 127, 128, 129 };
    const gain: f32 = -0.375;

    for (lengths) |len| {
        var simd = [_]f32{0} ** 129;
        var scalar = [_]f32{0} ** 129;

        for (0..len) |i| {
            const value: f32 = @floatFromInt(@as(i32, @intCast(i)) - 64);
            simd[i] = value * 0.125;
            scalar[i] = simd[i] * gain;
        }

        multiplySlice(simd[0..len], gain);
        try std.testing.expectEqualSlices(f32, scalar[0..len], simd[0..len]);

        for (len..simd.len) |i| {
            try std.testing.expectEqual(@as(f32, 0), simd[i]);
        }
    }
}

test "vector gain kernel preserves non finite values according to IEEE arithmetic" {
    var samples = [_]f32{ std.math.inf(f32), -std.math.inf(f32), std.math.nan(f32), 1 };
    multiplySlice(&samples, 2);

    try std.testing.expect(std.math.isPositiveInf(samples[0]));
    try std.testing.expect(std.math.isNegativeInf(samples[1]));
    try std.testing.expect(std.math.isNan(samples[2]));
    try std.testing.expectEqual(@as(f32, 2), samples[3]);
}

test "vector operations" {
    const a: @Vector(4, f32) = @splat(2);
    const b: @Vector(4, f32) = @splat(3);
    const c = add(4, a, b);
    try std.testing.expectEqual(@as(f32, 5), c[0]);
}
