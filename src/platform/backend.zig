const builtin = @import("builtin");
const types = @import("../core/types.zig");
const device = @import("../audio/device.zig");
const null_backend = @import("null/audio.zig");

pub const BackendKind = enum {
    auto,
    linux_pipewire,
    windows_wasapi,
    macos_coreaudio,
    null_backend,
};

pub fn defaultKind() BackendKind {
    return switch (builtin.os.tag) {
        .linux => .linux_pipewire,
        .windows => .windows_wasapi,
        .macos => .macos_coreaudio,
        else => .null_backend,
    };
}

pub fn create(kind: BackendKind) types.Result!device.AudioBackend {
    return switch (kind) {
        .null_backend => null_backend.create(),
        .linux_pipewire => if (builtin.os.tag == .linux)
            error.BackendUnavailable
        else
            error.Unsupported,
        .windows_wasapi => if (builtin.os.tag == .windows)
            error.BackendUnavailable
        else
            error.Unsupported,
        .macos_coreaudio => if (builtin.os.tag == .macos)
            error.BackendUnavailable
        else
            error.Unsupported,
        .auto => create(defaultKind()),
    };
}
