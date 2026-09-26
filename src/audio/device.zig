const types = @import("../core/types.zig");
const buffer = @import("../core/audio_buffer.zig");

pub const AudioBuffer = buffer.AudioBuffer;
pub const DeviceCallback = *const fn (?*anyopaque, ?*const AudioBuffer, *AudioBuffer, *const types.ProcessContext) void;

pub const AudioDeviceConfig = struct {
    direction: types.DeviceDirection = .output,
    format: types.AudioFormat = .{ .sample_rate = 48_000, .channels = 2 },
    block_size: types.FrameCount = 128,
    callback: DeviceCallback,
    user_data: ?*anyopaque = null,
};

pub const AudioDevice = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*anyopaque) void,
        start: *const fn (*anyopaque) types.Result!void,
        stop: *const fn (*anyopaque) types.Result!void,
        isRunning: *const fn (*anyopaque) bool,
        format: *const fn (*anyopaque) types.AudioFormat,
    };

    pub fn deinit(self: *AudioDevice) void { self.vtable.deinit(self.ptr); }
    pub fn start(self: *AudioDevice) types.Result!void { return self.vtable.start(self.ptr); }
    pub fn stop(self: *AudioDevice) types.Result!void { return self.vtable.stop(self.ptr); }
    pub fn isRunning(self: *const AudioDevice) bool { return self.vtable.isRunning(self.ptr); }
    pub fn format(self: *const AudioDevice) types.AudioFormat { return self.vtable.format(self.ptr); }
};

pub const AudioBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*anyopaque) void,
        enumerate: *const fn (*anyopaque, types.DeviceDirection, []types.DeviceInfo) types.Result!usize,
        open: *const fn (*anyopaque, types.DeviceId, AudioDeviceConfig) types.Result!AudioDevice,
    };

    pub fn deinit(self: *AudioBackend) void { self.vtable.deinit(self.ptr); }
    pub fn enumerate(self: *AudioBackend, direction: types.DeviceDirection, output: []types.DeviceInfo) types.Result!usize {
        return self.vtable.enumerate(self.ptr, direction, output);
    }
    pub fn open(self: *AudioBackend, device_id: types.DeviceId, config: AudioDeviceConfig) types.Result!AudioDevice {
        return self.vtable.open(self.ptr, device_id, config);
    }
};
