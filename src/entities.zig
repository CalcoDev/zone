const std = @import("std");
const rl = @import("raylib");

const gameState = @import("game.zig");
const calc = @import("calc.zig");

pub const EntityTag = enum {
    default,
    player,
    plant,
    max,
};

pub const Entity = struct {
    position: calc.v2f,
    tag: EntityTag,
    data: EntityData,

    pub fn tick(self: *Entity, state: *gameState.State) void {
        entityFunctionMap[@intFromEnum(self.tag)].tick(self, state);
    }

    pub fn draw(self: *Entity, state: *gameState.State) void {
        entityFunctionMap[@intFromEnum(self.tag)].draw(self, state);
    }
};

pub const EntityData = union(EntityTag) {
    default: void,
    player: PlayerData,
    plant: PlantData,
    max: void,
};

const PlayerData = struct {};
const PlantData = struct {};

// entity factory lmfao
pub fn makePlayer(position: calc.v2f) Entity {
    return Entity{
        .position = position,
        .tag = EntityTag.player,
        .data = .{
            .player = PlayerData{},
        },
    };
}

// entity funcs
const EntityTickFuncPtr = *const fn (*Entity, *gameState.State) void;
const EntityDrawFuncPtr = *const fn (*Entity, *gameState.State) void;
const EntityFuncMapping = struct {
    tick: EntityTickFuncPtr,
    draw: EntityDrawFuncPtr,
};

const entityFunctionMap = makeEntityFunctionMap(.{
    .{ .tag = EntityTag.default, .tick = entityTick, .draw = entityDraw },
    .{ .tag = EntityTag.player, .tick = playerTick, .draw = playerDraw },
    .{ .tag = EntityTag.plant, .tick = entityTick, .draw = entityDraw },
});

fn makeEntityFunctionMap(comptime pairs: anytype) [@intFromEnum(EntityTag.max)]EntityFuncMapping {
    // todo(calco): make this error message friendlier
    std.debug.assert(comptime pairs.len == @intFromEnum(EntityTag.max));

    var func_map: [@intFromEnum(EntityTag.max)]EntityFuncMapping = undefined;
    inline for (pairs) |pair| {
        func_map[@intFromEnum(pair.tag)] = EntityFuncMapping{
            .tick = pair.tick,
            .draw = pair.draw,
        };
    }
    return func_map;
}

fn entityTick(_: *Entity, _: *gameState.State) void {}

fn entityDraw(_: *Entity, _: *gameState.State) void {}

// player functions
fn playerTick(self: *Entity, game: *gameState.State) void {
    const old_p = self.position;
    const vel = game.input.movement.to_f32().normalize().scale(gameState.playerSpeed);
    self.position = self.position.add(vel);

    if (vel.sqrLen() > 0.0) {
        if (@abs(old_p.x - self.position.x) > @abs(old_p.y - self.position.y)) {
            const x = @round(self.position.x);
            const y = @round(self.position.y + (x - self.position.x) * vel.y / vel.x);
            self.position.y = y;
        } else if (@abs(old_p.x - self.position.x) <= @abs(old_p.y - self.position.y)) {
            const y = @round(self.position.y);
            const x = @round(self.position.x + (y - self.position.y) * vel.x / vel.y);
            self.position.x = x;
        }
    }

    game.rendering.game_camera.target = @bitCast(self.position.round());
}

fn playerDraw(self: *Entity, game: *gameState.State) void {
    rl.drawTexture(
        game.texture_bank.get_tex(gameState.TextureId.player),
        @intFromFloat(@round(self.position.x)),
        @intFromFloat(@round(self.position.y)),
        rl.Color.white,
    );
}
