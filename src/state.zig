const std = @import("std");
const assert = std.debug.assert;

const calc = @import("calc.zig");
const v2f = calc.v2f;
const v2i = calc.v2i;
const rect2f = calc.rect2f;
const rect2i = calc.rect2i;

const KeyState = enum { Pressed, Released, Down, Up };

const GameMode = enum { Intro, Game };

const State = struct {
    game_mode: GameMode = .Intro,

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
};
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
