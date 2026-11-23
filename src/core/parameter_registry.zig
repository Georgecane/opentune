const std = @import("std");
const parameter = @import("parameter.zig");

pub const max_parameters: usize = 256;

pub const RampMode = parameter.RampMode;

pub const ParameterSpec = struct {
    id: parameter.ParameterId,
    min_value: f32,
    max_value: f32,
    default_value: f32,

    pub fn isValid(self: ParameterSpec) bool {
        return self.id != 0 and
            std.math.isFinite(self.min_value) and
            std.math.isFinite(self.max_value) and
            std.math.isFinite(self.default_value) and
            self.min_value <= self.max_value and
            self.default_value >= self.min_value and
            self.default_value <= self.max_value;
    }

    pub fn accepts(self: ParameterSpec, value: f32) bool {
        return std.math.isFinite(value) and value >= self.min_value and value <= self.max_value;
    }
};

pub const RegisterResult = enum {
    registered,
    invalid_spec,
    duplicate_id,
    capacity_reached,
};

/// Fixed-capacity metadata registry. Populate before audio processing starts.
/// It owns no heap memory and is immutable while the audio thread is running.
pub const ParameterRegistry = struct {
    specs: [max_parameters]ParameterSpec = undefined,
    count: usize = 0,

    pub fn register(self: *ParameterRegistry, spec: ParameterSpec) RegisterResult {
        if (!spec.isValid()) return .invalid_spec;
        if (self.find(spec.id) != null) return .duplicate_id;
        if (self.count == self.specs.len) return .capacity_reached;
        self.specs[self.count] = spec;
        self.count += 1;
        return .registered;
    }

    pub fn find(self: *const ParameterRegistry, id: parameter.ParameterId) ?*const ParameterSpec {
        for (self.specs[0..self.count]) |*spec| {
            if (spec.id == id) return spec;
        }
        return null;
    }

    pub fn validateValue(self: *const ParameterRegistry, id: parameter.ParameterId, value: f32) bool {
        const spec = self.find(id) orelse return false;
        return spec.accepts(value);
    }
};

/// A deterministic parameter ramp. Call setTarget at the event's exact frame
/// boundary, then valueAt for each sample in the following render span.
pub const Ramp = struct {
    start_value: f32 = 0,
    target_value: f32 = 0,
    duration_frames: u32 = 0,
    elapsed_frames: u32 = 0,
    current_value: f32 = 0,
    linear_step: f32 = 0,
    exponential_factor: f32 = 1,
    mode: RampMode = .step,

    pub fn init(value: f32) Ramp {
        return .{ .start_value = value, .target_value = value, .current_value = value };
    }

    pub fn setTarget(
        self: *Ramp,
        target: f32,
        duration_frames: u32,
        mode: RampMode,
    ) bool {
        if (!std.math.isFinite(target)) return false;
        if (duration_frames > 0 and mode == .exponential and
            (self.currentValue() <= 0 or target <= 0))
        {
            return false;
        }
        self.start_value = self.currentValue();
        self.target_value = target;
        self.elapsed_frames = 0;
        if (duration_frames == 0 or mode == .step) {
            self.duration_frames = 0;
            self.mode = .step;
            self.current_value = target;
            return true;
        }

        self.duration_frames = duration_frames;
        self.current_value = self.start_value;
        self.mode = mode;
        if (mode == .linear) {
            self.linear_step = (target - self.start_value) / @as(f32, @floatFromInt(duration_frames));
        } else if (mode == .exponential) {
            self.exponential_factor = std.math.pow(
                f32,
                target / self.start_value,
                1.0 / @as(f32, @floatFromInt(duration_frames)),
            );
        }
        return true;
    }

    pub fn currentValue(self: *const Ramp) f32 {
        return self.current_value;
    }

    /// Returns the value for this sample, then advances the ramp by one frame.
    /// Linear and exponential coefficients are prepared once when the target changes.
    pub fn advance(self: *Ramp) f32 {
        const value = self.current_value;
        if (self.elapsed_frames < self.duration_frames) {
            self.elapsed_frames += 1;
            if (self.elapsed_frames >= self.duration_frames) {
                self.current_value = self.target_value;
            } else switch (self.mode) {
                .step => self.current_value = self.target_value,
                .linear => self.current_value += self.linear_step,
                .exponential => self.current_value *= self.exponential_factor,
            }
        }
        return value;
    }

    pub fn valueAt(self: *const Ramp, frame: u32) f32 {
        if (self.mode == .step or self.duration_frames == 0 or frame >= self.duration_frames) {
            return self.target_value;
        }
        const t = @as(f32, @floatFromInt(frame)) / @as(f32, @floatFromInt(self.duration_frames));
        return switch (self.mode) {
            .step => self.target_value,
            .linear => self.start_value + (self.target_value - self.start_value) * t,
            .exponential => self.start_value * std.math.pow(f32, self.target_value / self.start_value, t),
        };
    }
};

test "registry validates ranges and rejects duplicate and invalid identifiers" {
    var registry = ParameterRegistry{};
    try std.testing.expectEqual(RegisterResult.registered, registry.register(.{
        .id = 1,
        .min_value = 0,
        .max_value = 1,
        .default_value = 0.5,
    }));
    try std.testing.expectEqual(RegisterResult.duplicate_id, registry.register(.{
        .id = 1,
        .min_value = 0,
        .max_value = 2,
        .default_value = 1,
    }));
    try std.testing.expectEqual(RegisterResult.invalid_spec, registry.register(.{
        .id = 2,
        .min_value = 2,
        .max_value = 1,
        .default_value = 1,
    }));
    try std.testing.expectEqual(RegisterResult.invalid_spec, registry.register(.{
        .id = 0,
        .min_value = 0,
        .max_value = 1,
        .default_value = 0,
    }));
    try std.testing.expect(registry.validateValue(1, 0.25));
    try std.testing.expect(!registry.validateValue(1, 1.25));
    try std.testing.expect(!registry.validateValue(99, 0.5));
}

test "linear ramp is exact at start midpoint and endpoint" {
    var ramp = Ramp.init(0);
    try std.testing.expect(ramp.setTarget(1, 4, .linear));
    try std.testing.expectEqual(@as(f32, 0), ramp.valueAt(0));
    try std.testing.expectEqual(@as(f32, 0.5), ramp.valueAt(2));
    try std.testing.expectEqual(@as(f32, 1), ramp.valueAt(4));
    try std.testing.expectEqual(@as(f32, 1), ramp.valueAt(8));
}

test "ramp advance is sample-stepped and retargets from the current value" {
    var ramp = Ramp.init(0);
    try std.testing.expect(ramp.setTarget(1, 4, .linear));
    try std.testing.expectEqual(@as(f32, 0), ramp.advance());
    try std.testing.expectEqual(@as(f32, 0.25), ramp.advance());
    try std.testing.expect(ramp.setTarget(0.75, 2, .linear));
    try std.testing.expectEqual(@as(f32, 0.5), ramp.currentValue());
    try std.testing.expectEqual(@as(f32, 0.5), ramp.advance());
    try std.testing.expectEqual(@as(f32, 0.625), ramp.advance());
    try std.testing.expectEqual(@as(f32, 0.75), ramp.currentValue());
}

test "exponential ramp requires positive endpoints" {
    var ramp = Ramp.init(1);
    try std.testing.expect(ramp.setTarget(16, 4, .exponential));
    try std.testing.expectEqual(@as(f32, 4), ramp.valueAt(2));
    try std.testing.expect(!ramp.setTarget(0, 4, .exponential));
}

test "step and zero duration ramps apply immediately" {
    var ramp = Ramp.init(0.25);
    try std.testing.expect(ramp.setTarget(0.75, 0, .linear));
    try std.testing.expectEqual(@as(f32, 0.75), ramp.valueAt(0));
    try std.testing.expectEqual(@as(f32, 0.75), ramp.currentValue());
    try std.testing.expectEqual(@as(f32, 0.75), ramp.advance());

    var zero_start = Ramp.init(0);
    try std.testing.expect(zero_start.setTarget(1, 0, .exponential));
    try std.testing.expectEqual(@as(f32, 1), zero_start.currentValue());
}

[executed on device: hackgod (7cb235f1-4070-4c23-ba24-3e4337dda8d5)]