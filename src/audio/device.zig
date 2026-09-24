const types = @import("../core/types.zig");
const buffer_module = @import("../core/audio_buffer.zig");

pub const AudioBuffer = buffer_module.AudioBuffer;
pub const DeviceCallback = *const fn (
    user_data: ?*anyopaque,
    input: ?*const AudioBuffer,
    output: *AudioBuffer,
    context: *const types.ProcessContext,
) void;

pub const AudioDeviceConfig = struct {
    direction: types.DeviceDirection = .output,
    format: types.AudioFormat = .{
        .sample_rate = 48_000,
        .channels = 2,
    },
    block_size: types.FrameCount = 128,
    callback: DeviceCallback,
    user_data: ?*anyopaque = null,
};

pub const AudioDevice = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        start: *const fn (ptr: *anyopaque) types.Result!void,
        stop: *const fn (ptr: *anyopaque) types.Result!void,
        isRunning: *const fn (ptr: *anyopaque) bool,
        format: *const fn (ptr: *anyopaque) types.AudioFormat,
    };

    pub fn deinit(self: *AudioDevice) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn start(self: *AudioDevice) types.Result!void {
        return self.vtable.start(self.ptr);
    }

    pub fn stop(self: *AudioDevice) types.Result!void {
        return self.vtable.stop(self.ptr);
    }

    pub fn isRunning(self: *const AudioDevice) bool {
        return self.vtable.isRunning(self.ptr);
    }

    pub fn format(self: *const AudioDevice) types.AudioFormat {
        return self.vtable.format(self.ptr);
    }
};

pub const AudioBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        enumerate: *const fn (
            ptr: *anyopaque,
            direction: types.DeviceDirection,
            output: []types.DeviceInfo,
        ) types.Result!usize,
        open: *const fn (
            ptr: *anyopaque,
            device_id: types.DeviceId,
            config: AudioDeviceConfig,
        ) types.Result!AudioDevice,
    };

    pub fn deinit(self: *AudioBackend) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn enumerate(
        self: *AudioBackend,
        direction: types.DeviceDirection,
        output: []types.DeviceInfo,
    ) types.Result!usize {
        return self.vtable.enumerate(self.ptr, direction, output);
    }

    pub fn open(
        self: *AudioBackend,
        device_id: types.DeviceId,
        config: AudioDeviceConfig,
    ) types.Result!AudioDevice {
        return self.vtable.open(self.ptr, device_id, config);
    }
};
