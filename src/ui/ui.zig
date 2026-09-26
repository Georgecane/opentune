pub const UiBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*anyopaque) void,
        run: *const fn (*anyopaque) void,
    };

    pub fn deinit(self: *UiBackend) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn run(self: *UiBackend) void {
        self.vtable.run(self.ptr);
    }
};
