// Import real-time modules as test roots so Zig includes tests declared in
// each module and its imported dependencies.
test {
    _ = @import("audio/engine.zig");
    _ = @import("core/spsc_queue.zig");
    _ = @import("core/parameter.zig");
    _ = @import("core/parameter_registry.zig");
}

[executed on device: hackgod (7cb235f1-4070-4c23-ba24-3e4337dda8d5)]