const std = @import("std");

const rl = @cImport(@cInclude("raylib.h"));

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

var game: gameState.State = undefined;

pub fn main() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);
    // rl.setExitKey(rl.KeyboardKey.null);

    // const shader = rl.loadShader("res/shaders/default.vert", "res/shaders/default.frag") catch unreachable;

    // game = try gameState.State.init();
    // game.sceneIntro();
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);
        rl.EndDrawing();
        // try game.tick();
        // try game.draw();
    }
    // game.deinit();

    rl.CloseWindow();
}
