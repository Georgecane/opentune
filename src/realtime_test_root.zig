// Import real-time modules as test roots so Zig includes tests declared in
// each module and its imported dependencies.
test {
    _ = @import("audio/engine.zig");
    _ = @import("core/spsc_queue.zig");
}
