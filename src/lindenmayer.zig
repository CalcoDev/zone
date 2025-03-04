const std = @import("std");

const rl = @import("raylib");

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

pub const LSystemRuleReplace = union(enum) {
    string: []const u8,
};

pub const LSystemRule = struct {
    og: u8,
    replace: LSystemRuleReplace,
};

// pub const LSystemDrawFunc = *const fn ([]const u8) void;
pub const LSystemDrawFunc = *const fn ([]const u8, *entities.Entity, *gameState.State) void;

pub const LindemayerSystem = struct {
    rules: []const LSystemRule,
    draw_func: LSystemDrawFunc,

    pub fn init(rules: []const LSystemRule, draw_func: LSystemDrawFunc) LindemayerSystem {
        return LindemayerSystem{
            .rules = rules,
            .draw_func = draw_func,
        };
    }

    pub fn step(self: *LindemayerSystem, allocator: std.mem.Allocator, current: []const u8) []const u8 {
        const new_length = self.peekLength(current);
        const new = allocator.alloc(u8, new_length) catch unreachable;
        var idx: usize = 0;
        for (current) |c| {
            if (self.get_rule(c)) |rule| {
                switch (rule.replace) {
                    .string => |s| {
                        @memcpy(new[idx..][0..s.len], s);
                        idx += s.len;
                    },
                }
            } else {
                new[idx] = c;
                idx += 1;
            }
        }
        return new;
    }

    pub fn draw(self: *LindemayerSystem, current: []const u8, entity: *entities.Entity, game: *gameState.State) void {
        self.draw_func(current, entity, game);
    }

    fn peekLength(self: *LindemayerSystem, current: []const u8) usize {
        var length: usize = 0;
        for (current) |c| {
            if (self.get_rule(c)) |rule| {
                length += switch (rule.replace) {
                    .string => |s| s.len,
                };
            } else {
                length += 1;
            }
        }
        return length;
    }

    fn get_rule(self: *LindemayerSystem, og: u8) ?LSystemRule {
        var i: usize = 0;
        while (i < self.rules.len) : (i += 1) {
            if (self.rules[i].og == og) {
                return self.rules[i];
            }
        }
        return null;
    }
};

const BallsLSystemRules = [_]LSystemRule{
    .{ .og = '1', .replace = .{ .string = "11" } },
    .{ .og = '0', .replace = .{ .string = "1[0]0" } },
};
pub const BallsLSystem = LindemayerSystem.init(&BallsLSystemRules, &drawBallsSystem);
fn drawBallsSystem(current: []const u8, entity: *entities.Entity, game: *gameState.State) void {
    const lLen: f32 = 10.0;

    var stack = std.ArrayList(struct { pos: calc.v2f, angle: f32 }).init(game.allocation.allocator);
    defer stack.deinit();

    var ppos: calc.v2f = entity.position;
    var pangle: f32 = -std.math.pi / 2.0;

    stack.append(.{ .pos = entity.position, .angle = -std.math.pi / 2.0 }) catch unreachable;
    for (current) |c| {
        switch (c) {
            '0' => {
                const np = ppos.add(calc.v2f.init_angle(pangle).scale(lLen));
                rl.drawLine(
                    @intFromFloat(ppos.x),
                    @intFromFloat(ppos.y),
                    @intFromFloat(np.x),
                    @intFromFloat(np.y),
                    rl.Color.red,
                );
                ppos = np;
            },
            '1' => {
                const np = ppos.add(calc.v2f.init_angle(pangle).scale(lLen));
                rl.drawLine(
                    @intFromFloat(ppos.x),
                    @intFromFloat(ppos.y),
                    @intFromFloat(np.x),
                    @intFromFloat(np.y),
                    rl.Color.red,
                );
                ppos = np;
            },
            '[' => {
                stack.append(.{ .pos = ppos, .angle = pangle }) catch unreachable;
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
