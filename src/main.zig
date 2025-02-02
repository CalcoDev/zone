const std = @import("std");

const rl = @import("raylib");

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

var game: gameState.State = undefined;

pub fn main() !void {
    rl.initWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.setTargetFPS(gameState.gameFps);
    rl.setExitKey(rl.KeyboardKey.null);

    game = try gameState.State.init();
    game.sceneIntro();
    while (!rl.windowShouldClose()) {
        try game.tick();
        try game.draw();
    }
    game.deinit();

    rl.closeWindow();
}
