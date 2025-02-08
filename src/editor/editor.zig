pub fn Editor(comptime TSelf: type) type {
    return struct {
        data: TSelf,

        init: *const fn (self: *TSelf) void,
        deinit: *const fn (self: *TSelf) void,
        tick: *const fn (self: *TSelf) void,
        draw: *const fn (self: *TSelf) void,
    };
}
