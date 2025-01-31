const std = @import("std");

const rl = @import("raylib");

const k = @import("const.zig");

const calc = @import("calc.zig");
const v2f = calc.v2f;
const v2i = calc.v2i;
const rect2f = calc.rect2f;
const rect2i = calc.rect2i;

const _state = @import("state.zig");
const Trigger = _state.Trigger;
const state = &_state.state;

fn gameInit() void {
    state.input.enabled = false;
    state.game_mode = .Intro;
    state.intro.start = Trigger.now();
}

fn gameTick() void {
    if (state.game_mode == .Intro) {
        const ticks = state.intro.start.get_since();
        if (ticks > k.introDuration) {
            state.game_mode = .Game;
            state.input.enabled = true;
        }
    }
}

fn gameDraw() !void {
    rl.clearBackground(rl.Color.black);
    if (state.game_mode == .Intro) {
        const font = try rl.getFontDefault();
        const textRect: rect2f = .{
            .pos = v2f.init(0, 0),
            .size = @bitCast(rl.measureTextEx(font, k.introText, k.introFontSize, 2.0)),
        };

        const screenRect = rect2f.init(0, 0, k.gameWidth, k.gameHeight);
        const centeredPos: v2f = rect2f.center_pos(textRect, screenRect);

        const ticks = state.intro.start.get_since();
        const alpha = 1.0 - @as(f32, @floatFromInt(ticks)) / @as(f32, @floatFromInt(k.introDuration));
        rl.drawTextEx(font, k.introText, @bitCast(centeredPos), k.introFontSize, 2.0, rl.colorAlpha(rl.Color.white, alpha));
    } else if (state.game_mode == .Game) {
        // const pos = rect2f.center_pos()
        rl.drawText("game mode", 20, 20, 20, rl.Color.white);
    }
}

pub fn main() !void {
    rl.initWindow(k.winWidth, k.winHeight, k.winTitle);
    defer rl.closeWindow();
    rl.setTargetFPS(k.gameFps);

    const gameTex = try rl.loadRenderTexture(k.gameWidth, k.gameHeight);
    defer rl.unloadRenderTexture(gameTex);

    state.time.tick = 0;
    gameInit();

    while (!rl.windowShouldClose()) {
        state.time.tick += 1;
        gameTick();

        rl.beginTextureMode(gameTex);
        try gameDraw();
        rl.endTextureMode();

        // Draw the screen
        rl.beginDrawing();
        const srcRect = rl.Rectangle{ .x = 0, .y = 0, .width = k.gameWidth, .height = -k.gameHeight };
        const dstRect = rl.Rectangle{ .x = 0, .y = 0, .width = k.winWidth, .height = k.winHeight };
        rl.drawTexturePro(gameTex.texture, srcRect, dstRect, rl.Vector2{ .x = 0, .y = 0 }, 0, rl.Color.white);
        rl.endDrawing();
    }
}
