const std = @import("std");

const rl = @import("raylib");

const k = @import("const.zig");
const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

var game: gameState.State = undefined;

// fn gameTick() void {
//     game.tick_internal();

//     if (state.game_mode == .Intro) {
//         const ticks = state.intro.start.get_since();
//         if (ticks > k.introDuration) {
//             state.game_mode = .Game;
//             state.input.enabled = true;
//         }
//     } else {
//         for (state.game.entities.items) |*entity| {
//             gameTickEntity(entity);
//         }
//     }
// }

// fn gameDrawEntity(e: entities.Entity) void {
//     switch (e.e_type) {
//         .default => {},
//         .player => {
//             rl.drawTexture(
//                 state.textures[@intFromEnum(TextureType.Player)].texture,
//                 @intFromFloat(e.position.x),
//                 @intFromFloat(e.position.y),
//                 rl.Color.white,
//             );
//         },
//         .plant => {},
//     }
// }

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
