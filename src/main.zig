const std = @import("std");

const rl = @import("raylib");

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

var game: gameState.State = undefined;

pub fn main() !void {
    rl.initWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.setTargetFPS(gameState.gameFps);
    // rl.setExitKey(rl.KeyboardKey.null);

    // const shader = rl.loadShader("res/shaders/default.vert", "res/shaders/default.frag") catch unreachable;

    // game = try gameState.State.init();
    // game.sceneIntro();
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        rl.endDrawing();
        // try game.tick();
        // try game.draw();
    }
    // game.deinit();

    rl.closeWindow();
}
