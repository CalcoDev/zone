// TODO(calco): refactor this out of the code base it is too bad
pub fn Editor(comptime TData: type) type {
    return struct {
        data: TData,

        _init: *const fn (self: *TData) void,
        _deinit: *const fn (self: *TData) void,
        _tick: *const fn (self: *TData) void,
        _draw: *const fn (self: *TData) void,

        const Self = @This();
        pub fn init(self: *Self) void {
            self._init(&self.data);
        }
        pub fn deinit(self: *Self) void {
            self._deinit(&self.data);
        }
        pub fn tick(self: *Self) void {
            self._tick(&self.data);
        }
        pub fn draw(self: *Self) void {
            self._draw(&self.data);
        }
    };
}
