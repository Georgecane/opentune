// Import the engine module as a test root so Zig includes tests declared in
// the engine and its imported core modules.
test {
    _ = @import("audio/engine.zig");
}
