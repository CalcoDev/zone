const rl = @import("raylib");

const std = @import("std");
const assert = std.debug.assert;

const entities = @import("entities.zig");
const k = @import("const.zig");

const calc = @import("calc.zig");
const v2f = calc.v2f;
const v2i = calc.v2i;
const rect2f = calc.rect2f;
const rect2i = calc.rect2i;

pub const KeyState = enum { Pressed, Released, Down, Up };

pub const GameMode = enum { Intro, Game };

pub const TextureType = enum { Player, Max };

pub const Texture = struct {
    path: [*:0]const u8,
    texture: rl.Texture2D,
};

fn emptyRaylibTexture() rl.Texture2D {
    return rl.Texture2D{
        .id = 0,
        .width = 0,
        .height = 0,
        .mipmaps = 0,
        .format = @enumFromInt(1),
    };
}

pub const State = struct {
    game_mode: GameMode = .Intro,
    textures: [@intFromEnum(TextureType.Max)]Texture = [@intFromEnum(TextureType.Max)]Texture{.{
        .path = "res/player.png",
        .texture = emptyRaylibTexture(),
    }},

    time: struct {
        tick: u32 = 0,
    } = .{},

    input: struct {
        enabled: bool = false,
        pause: KeyState = .Up,
        movement: v2i = v2i.init(0, 0),
    } = .{},

    intro: struct {
        start: Trigger = .{},
        text_rect: rect2f = .{},
    } = .{},

    game: struct {
        camera: rl.Camera2D = rl.Camera2D{
            .zoom = 1.0,
            .rotation = 0.0,
            .offset = rl.Vector2.init(k.gameWidth / 2, k.gameHeight / 2),
            .target = rl.Vector2.init(0, 0),
        },
        // we guarantee player will always be the first thing here ?
        entities: std.ArrayList(entities.Entity) = std.ArrayList(entities.Entity).init(arena.allocator()),
    } = .{},
};
pub var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub var state: State = .{};

pub const Trigger = struct {
    const DisabledTicks = 0xFF_FF_FF_FF;
    tick: u32 = DisabledTicks,

    pub fn disable(t: *Trigger) void {
        t.tick = DisabledTicks;
    }

    pub fn now() Trigger {
        return Trigger{ .tick = state.time.tick };
    }

    pub fn is_now(t: Trigger) bool {
        return t.tick == state.time.tick;
    }

    pub fn get_since(t: Trigger) u32 {
        if (state.time.tick >= t.tick) {
            return state.time.tick - t.tick;
        } else {
            return Trigger.DisabledTicks;
        }
    }

    pub fn is_between(t: Trigger, start: u32, end: u32) bool {
        assert(end >= start);
        if (t.tick != Trigger.DisabledTicks) {
            const ticks = get_since(t);
            return (ticks >= start) and (ticks < end);
        } else {
            return false;
        }
    }
};
