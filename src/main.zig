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
const TextureType = _state.TextureType;
const state = &_state.state;
const arena = &_state.arena;

const entities = @import("entities.zig");

fn gameInit() !void {
    state.input.enabled = false;
    state.game_mode = .Intro;
    state.intro.start = Trigger.now();

    for (&state.textures) |*texture| {
        texture.texture = try rl.loadTexture(texture.path);
    }

    try gameInitGameplayScene();
}

fn gameInitGameplayScene() !void {
    const player = entities.Entity.make_player();
    try state.game.entities.append(player);
}

fn gameTick() void {
    if (state.game_mode == .Intro) {
        const ticks = state.intro.start.get_since();
        if (ticks > k.introDuration) {
            state.game_mode = .Game;
            state.input.enabled = true;
        }
    } else {
        for (state.game.entities.items) |*entity| {
            gameTickEntity(entity);
        }
    }
}

fn gameTickEntity(e: *entities.Entity) void {
    switch (e.e_type) {
        .default => {},
        .player => {
            const v = state.input.movement.to_f32().normalize().scale(k.playerSpeed);
            e.position = e.position.add(v);

            state.game.camera.target = @bitCast(e.position);
        },
        .plant => {},
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
        rl.beginMode2D(state.game.camera);

        rl.drawText("game mode", 20, 20, 20, rl.Color.white);

        for (state.game.entities.items) |entity| {
            gameDrawEntity(entity);
        }

        rl.endMode2D();
    }
}

fn gameDrawEntity(e: entities.Entity) void {
    switch (e.e_type) {
        .default => {},
        .player => {
            rl.drawTexture(
                state.textures[@intFromEnum(TextureType.Player)].texture,
                @intFromFloat(e.position.x),
                @intFromFloat(e.position.y),
                rl.Color.white,
            );
        },
        .plant => {},
    }
}

fn gameUninit() void {
    for (state.textures) |texture| {
        rl.unloadTexture(texture.texture);
    }

    state.game.entities.deinit();
    arena.deinit();
}

fn getKeyStateFromRaylib(key: rl.KeyboardKey) _state.KeyState {
    if (rl.isKeyPressed(key)) {
        return _state.KeyState.Pressed;
    } else if (rl.isKeyReleased(key)) {
        return _state.KeyState.Released;
    } else if (rl.isKeyDown(key)) {
        return _state.KeyState.Down;
    } else if (rl.isKeyUp(key)) {
        return _state.KeyState.Up;
    }
    unreachable;
}

// const lSys = "0";
// const lSys = "11[1[0]0]1[0]0";
var lSys: []const u8 = "0";
const lLen: f32 = 10.0 * 1.0;

fn stepLSystem(system: []const u8) ![]const u8 {
    var str = std.ArrayList(u8).init(std.heap.page_allocator);
    defer str.deinit();
    // var i: usize = 0;
    // while (system[i] != 0) {
    for (system) |c| {
        try switch (c) {
            '1' => {
                try str.appendSlice("11");
            },
            '0' => {
                try str.appendSlice("1[0]0");
            },
            else => str.append(c),
        };

        // i += 1;
    }
    return str.toOwnedSlice();
}

fn drawLSystem(system: []const u8, pos: v2f, angle: f32) !void {
    var stack = std.ArrayList(struct { pos: v2f, angle: f32 }).init(arena.allocator());
    defer stack.deinit();

    var ppos = pos;
    var pangle = angle;

    try stack.append(.{ .pos = pos, .angle = angle });
    // var i: usize = 0;
    // while (system[i] != 0) {
    for (system) |c| {
        switch (c) {
            '0' => {
                const np = ppos.add(v2f.init_angle(pangle).scale(lLen));
                rl.drawLine(
                    @intFromFloat(ppos.x),
                    @intFromFloat(ppos.y),
                    @intFromFloat(np.x),
                    @intFromFloat(np.y),
                    rl.Color.red,
                    // ([_]rl.Color{ rl.Color.red, rl.Color.green, rl.Color.yellow })[@intCast(@mod(i, 3))],
                );
                ppos = np;
            },
            '1' => {
                const np = ppos.add(v2f.init_angle(pangle).scale(lLen));
                rl.drawLine(
                    @intFromFloat(ppos.x),
                    @intFromFloat(ppos.y),
                    @intFromFloat(np.x),
                    @intFromFloat(np.y),
                    rl.Color.red,
                    // ([_]rl.Color{ rl.Color.red, rl.Color.green, rl.Color.yellow })[@intCast(@mod(i, 3))],
                );
                ppos = np;
            },
            '[' => {
                try stack.append(.{ .pos = ppos, .angle = pangle });
                pangle -= std.math.pi / 4.0;
            },
            ']' => {
                const last = stack.pop();
                ppos = last.pos;
                pangle = last.angle + std.math.pi / 4.0;
            },
            else => {},
        }
    }
}

pub fn main() !void {
    rl.initWindow(k.winWidth, k.winHeight, k.winTitle);
    defer rl.closeWindow();
    rl.setTargetFPS(k.gameFps);

    const gameTex = try rl.loadRenderTexture(k.gameWidth, k.gameHeight);
    defer rl.unloadRenderTexture(gameTex);

    state.time.tick = 0;
    try gameInit();
    defer gameUninit();

    rl.setExitKey(rl.KeyboardKey.null);

    while (!rl.windowShouldClose()) {
        state.time.tick += 1;
        if (state.input.enabled) {
            state.input.movement = v2i.init(
                @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.d))) - @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.a))),
                @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.s))) - @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.w))),
            );
            state.input.pause = getKeyStateFromRaylib(rl.KeyboardKey.escape);
        }
        gameTick();

        rl.beginTextureMode(gameTex);
        // try gameDraw();

        rl.clearBackground(rl.Color.black);
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            lSys = try stepLSystem(lSys);
        }
        try drawLSystem(lSys, v2f.init(k.gameWidth / 2, k.gameHeight), -std.math.pi / 2.0);

        // rl.drawLine(20, 20, 20, 30, rl.Color.green);

        rl.endTextureMode();

        // Draw the screen
        rl.beginDrawing();
        const srcRect = rl.Rectangle{ .x = 0, .y = 0, .width = k.gameWidth, .height = -k.gameHeight };
        const dstRect = rl.Rectangle{ .x = 0, .y = 0, .width = k.winWidth, .height = k.winHeight };
        rl.drawTexturePro(gameTex.texture, srcRect, dstRect, rl.Vector2{ .x = 0, .y = 0 }, 0, rl.Color.white);
        rl.endDrawing();
    }
}
