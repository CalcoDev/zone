const std = @import("std");
const assert = std.debug.assert;

const rl = @import("raylib");

const calc = @import("calc.zig");
const misc = @import("misc.zig");
const entities = @import("entities.zig");

pub const winTitle = "Zone.";
pub const winWidth: i32 = 1280;
pub const winHeight: i32 = 720;

const gameSizeScale: i32 = 1;
pub const gameFps: i32 = 240;
pub const gameWidth: i32 = 320 * gameSizeScale;
pub const gameHeight: i32 = 180 * gameSizeScale;

pub const playerSpeed: f32 = 0.5;

pub const introText = "ZONE.";
pub const introFontSize = 20;
pub const introDuration = gameFps * 2;

pub const TextureId = enum {
    player,
    max,
};

pub const TextureBank = struct {
    map: [@intFromEnum(TextureId.max)]rl.Texture2D,

    pub fn init() !TextureBank {
        var bank_map: [@intFromEnum(TextureId.max)]rl.Texture2D = undefined;
        bank_map[@intFromEnum(TextureId.player)] = try rl.loadTexture("res/player.png");
        return TextureBank{
            .map = bank_map,
        };
    }

    pub fn deinit(self: *TextureBank) void {
        for (self.map) |tex| {
            rl.unloadTexture(tex);
        }
    }

    pub fn get_tex(self: *TextureBank, id: TextureId) rl.Texture2D {
        return self.map[@intFromEnum(id)];
    }
};

pub const GameScene = enum { intro, game };

pub const State = struct {
    texture_bank: TextureBank,

    game_scene: GameScene,

    allocation: StateAllocation,
    timing: StateTiming,
    input: StateInput,
    rendering: StateRendering,

    intro_data: StateIntroData,
    gameplay_data: StateGameplayData,

    pub fn init() !State {
        var state = State{
            .texture_bank = try TextureBank.init(),
            .game_scene = GameScene.intro,
            .allocation = StateAllocation.init(),
            .timing = StateTiming.init(),
            .input = StateInput.init(),
            .rendering = try StateRendering.init(),
            .intro_data = StateIntroData.init(),
            .gameplay_data = undefined,
        };
        state.gameplay_data = StateGameplayData.init(&state);
        return state;
    }

    pub fn deinit(self: *State) void {
        self.texture_bank.deinit();
        self.rendering.deinit();
        self.allocation.deinit();
        self.gameplay_data.deinit();
    }

    pub fn tick(self: *State) !void {
        self.timing.tick_internal();
        self.input.tick_internal();

        switch (self.game_scene) {
            GameScene.intro => {
                const ticks = self.timing.get_since(self.intro_data.start);
                if (self.input.skip_intro == KeyState.pressed or ticks > introDuration) {
                    self.sceneGameplay();
                }
            },
            GameScene.game => {
                for (self.gameplay_data.entities.items) |*entity| {
                    entity.tick(self);
                }
            },
        }
    }

    pub fn draw(self: *State) !void {
        self.rendering.bindGameTexture();
        rl.clearBackground(rl.Color.black);

        switch (self.game_scene) {
            GameScene.intro => {
                const font = try rl.getFontDefault();
                const textRect: calc.rect2f = .{
                    .pos = calc.v2f.init(0, 0),
                    .size = @bitCast(rl.measureTextEx(font, introText, introFontSize, 2.0)),
                };

                const screenRect = calc.rect2f.init(0, 0, gameWidth, gameHeight);
                const centeredPos: calc.v2f = calc.rect2f.center_pos(textRect, screenRect);

                const ticks = self.timing.get_since(self.intro_data.start);
                const alpha = 1.0 - @as(f32, @floatFromInt(ticks)) / @as(f32, @floatFromInt(introDuration));
                rl.drawTextEx(font, introText, @bitCast(centeredPos), introFontSize, 2.0, rl.colorAlpha(rl.Color.white, alpha));
            },
            GameScene.game => {
                self.rendering.bindGameCamera();
                for (self.gameplay_data.entities.items) |*entity| {
                    entity.draw(self);
                }
            },
        }

        self.rendering.renderToScreen();
    }

    pub fn sceneIntro(self: *State) void {
        self.game_scene = .intro;
        self.intro_data.start = self.timing.now();
    }

    pub fn sceneGameplay(self: *State) void {
        self.game_scene = .game;
        self.gameplay_data.entities.clearAndFree();
        self.gameplay_data.entities.append(entities.makePlayer(calc.v2f{ .x = 0, .y = 0 })) catch unreachable;
    }
};

const StateAllocation = struct {
    allocator: std.mem.Allocator,

    pub fn init() StateAllocation {
        return StateAllocation{
            .allocator = std.heap.page_allocator,
        };
    }

    pub fn deinit(_: *StateAllocation) void {}
};

const StateRendering = struct {
    game_camera: rl.Camera2D,
    game_texture: rl.RenderTexture2D,
    screen_texture: rl.RenderTexture2D,

    current_bound: ?*rl.RenderTexture2D,

    pub fn init() !StateRendering {
        return StateRendering{
            .game_camera = rl.Camera2D{
                .offset = rl.Vector2.init(gameWidth / 2, gameHeight / 2),
                .target = rl.Vector2.init(0, 0),
                .rotation = 0.0,
                .zoom = 1.0,
            },
            .game_texture = try rl.loadRenderTexture(gameWidth, gameHeight),
            .screen_texture = try rl.loadRenderTexture(winWidth, winHeight),
            .current_bound = null,
        };
    }

    pub fn deinit(self: *StateRendering) void {
        rl.unloadRenderTexture(self.game_texture);
        rl.unloadRenderTexture(self.screen_texture);
    }

    pub fn bindGameTexture(self: *StateRendering) void {
        self.unbindCurrent(&self.game_texture);
        rl.beginTextureMode(self.game_texture);
    }

    pub fn bindScreenTexture(self: *StateRendering) void {
        self.unbindCurrent(&self.screen_texture);
        rl.beginTextureMode(self.screen_texture);
    }

    pub fn bindGameCamera(self: *StateRendering) void {
        rl.beginMode2D(self.game_camera);
    }

    pub fn unbindGameCamera(_: *StateRendering) void {
        rl.endMode2D();
    }

    fn unbindCurrent(self: *StateRendering, newBound: ?*rl.RenderTexture2D) void {
        if (self.current_bound != null) {
            rl.endTextureMode();
            if (self.current_bound == &self.game_texture) {
                rl.endMode2D();
            }
            self.current_bound = newBound;
        } else {
            self.current_bound = newBound;
        }
    }

    pub fn renderToScreen(self: *StateRendering) void {
        self.unbindCurrent(null);
        rl.beginDrawing();
        rl.drawTexturePro(
            self.game_texture.texture,
            rl.Rectangle{ .x = 0, .y = 0, .width = gameWidth, .height = -gameHeight },
            rl.Rectangle{ .x = 0, .y = 0, .width = winWidth, .height = winHeight },
            rl.Vector2{ .x = 0, .y = 0 },
            0,
            rl.Color.white,
        );
        rl.drawTexturePro(
            self.screen_texture.texture,
            rl.Rectangle{ .x = 0, .y = 0, .width = winWidth, .height = -winHeight },
            rl.Rectangle{ .x = 0, .y = 0, .width = winWidth, .height = winHeight },
            rl.Vector2{ .x = 0, .y = 0 },
            0,
            rl.Color.white,
        );
        rl.endDrawing();
    }
};

const StateTiming = struct {
    tick: u32 = 0,

    pub fn init() StateTiming {
        return StateTiming{
            .tick = 0,
        };
    }

    pub fn tick_internal(self: *StateTiming) void {
        self.tick += 1;
    }

    pub fn now(timing: *StateTiming) misc.Trigger {
        return misc.Trigger{ .tick = timing.tick };
    }

    pub fn is_now(timing: StateTiming, t: misc.Trigger) bool {
        return t.tick == timing.tick;
    }

    pub fn get_since(timing: StateTiming, t: misc.Trigger) u32 {
        if (timing.tick >= t.tick) {
            return timing.tick - t.tick;
        } else {
            return misc.Trigger.disabledTicks;
        }
    }

    pub fn is_between(timing: StateTiming, t: misc.Trigger, start: u32, end: u32) bool {
        assert(end >= start);
        if (t.tick != misc.Trigger.disabledTicks) {
            const ticks = timing.get_since(t);
            return (ticks >= start) and (ticks < end);
        } else {
            return false;
        }
    }
};

pub const KeyState = enum { pressed, released, down, up };
const StateInput = struct {
    enabled: bool,

    movement: calc.v2i,
    pause: KeyState,
    skip_intro: KeyState,

    pub fn init() StateInput {
        return StateInput{
            .enabled = true,
            .movement = calc.v2i.init(0, 0),
            .pause = KeyState.up,
            .skip_intro = KeyState.up,
        };
    }

    pub fn enabled(self: *StateInput) void {
        self.enabled = true;
    }

    pub fn disable(self: *StateInput) void {
        self.enabled = false;
    }

    fn getKeyStateFromRaylib(key: rl.KeyboardKey) KeyState {
        if (rl.isKeyPressed(key)) {
            return KeyState.pressed;
        } else if (rl.isKeyReleased(key)) {
            return KeyState.released;
        } else if (rl.isKeyDown(key)) {
            return KeyState.down;
        } else if (rl.isKeyUp(key)) {
            return KeyState.up;
        }
        unreachable;
    }

    pub fn tick_internal(self: *StateInput) void {
        self.skip_intro = getKeyStateFromRaylib(rl.KeyboardKey.space);
        if (self.enabled) {
            self.movement = calc.v2i.init(
                @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.d))) - @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.a))),
                @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.s))) - @as(i32, @intFromBool(rl.isKeyDown(rl.KeyboardKey.w))),
            );
            self.pause = getKeyStateFromRaylib(rl.KeyboardKey.escape);
        }
    }
};

const StateIntroData = struct {
    start: misc.Trigger,

    pub fn init() StateIntroData {
        return StateIntroData{
            .start = .{},
        };
    }
};

const StateGameplayData = struct {
    camera: rl.Camera2D,
    entities: std.ArrayList(entities.Entity),

    pub fn init(state: *State) StateGameplayData {
        return StateGameplayData{
            .camera = rl.Camera2D{
                .zoom = 1.0,
                .rotation = 0.0,
                .offset = rl.Vector2.init(gameWidth / 2, gameHeight / 2),
                .target = rl.Vector2.init(0, 0),
            },
            .entities = std.ArrayList(entities.Entity).init(state.allocation.allocator),
        };
    }

    pub fn deinit(self: *StateGameplayData) void {
        self.entities.deinit();
    }
};
