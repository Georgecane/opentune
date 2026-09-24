const types = @import("../../core/types.zig");
const device = @import("../../audio/device.zig");

const NullBackend = struct {};
var global_backend = NullBackend{};

const NullDevice = struct {
    format_value: types.AudioFormat,
    running: bool = false,

    fn deinit(ptr: *anyopaque) void {
        const self: *NullDevice = @ptrCast(@alignCast(ptr));
        self.running = false;
    }

    fn start(ptr: *anyopaque) types.Result!void {
        const self: *NullDevice = @ptrCast(@alignCast(ptr));
        self.running = true;
    }

    fn stop(ptr: *anyopaque) types.Result!void {
        const self: *NullDevice = @ptrCast(@alignCast(ptr));
        self.running = false;
    }

    fn isRunning(ptr: *anyopaque) bool {
        const self: *NullDevice = @ptrCast(@alignCast(ptr));
        return self.running;
    }

    fn format(ptr: *anyopaque) types.AudioFormat {
        const self: *NullDevice = @ptrCast(@alignCast(ptr));
        return self.format_value;
    }
};

var global_device = NullDevice{
    .format_value = .{
        .sample_rate = 48_000,
        .channels = 2,
    },
};

const null_device_vtable = device.AudioDevice.VTable{
    .deinit = NullDevice.deinit,
    .start = NullDevice.start,
    .stop = NullDevice.stop,
    .isRunning = NullDevice.isRunning,
    .format = NullDevice.format,
};

fn backendDeinit(_: *anyopaque) void {}

fn enumerate(
    _: *anyopaque,
    _: types.DeviceDirection,
    output: []types.DeviceInfo,
) types.Result!usize {
    if (output.len == 0) return 0;

    output[0] = .{
        .id = .{ .value = 0 },
        .name = "Null Device",
        .is_input = true,
        .is_output = true,
        .min_channels = 1,
        .max_channels = 64,
    };

    return 1;
}

fn open(
    _: *anyopaque,
    _: types.DeviceId,
    config: device.AudioDeviceConfig,
) types.Result!device.AudioDevice {
    global_device.format_value = config.format;
    global_device.running = false;

    return .{
        .ptr = &global_device,
        .vtable = &null_device_vtable,
    };
}

const backend_vtable = device.AudioBackend.VTable{
    .deinit = backendDeinit,
    .enumerate = enumerate,
    .open = open,
};

pub fn create() types.Result!device.AudioBackend {
    return .{
        .ptr = &global_backend,
        .vtable = &backend_vtable,
    };
}
