const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    rl.initWindow(1280, 720, "Raylib in Zig");

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        std.log.debug("Breakpoint?", .{});
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        rl.drawText("Hello raylib", 20, 20, 30, rl.Color.white);
        rl.endDrawing();
    }

    rl.closeWindow();
}
