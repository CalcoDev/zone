const std = @import("std");
const rl = @import("raylib");

const gameState = @import("game.zig");
const calc = @import("calc.zig");
const lsystem = @import("lindenmayer.zig");

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

    pub fn plant_step_system(self: *Entity, game: *gameState.State, free_old: bool) void {
        const new = self.data.plant.lsystem.step(game.allocation.allocator, self.data.plant.current);
        if (free_old) {
            game.allocation.allocator.free(self.data.plant.current);
        }
        std.log.debug("plant post step: {s}", .{new});
        self.data.plant.current = new;
        std.log.debug("plant new mem: {}", .{@intFromPtr(new.ptr)});
    }
};

pub const EntityData = union(EntityTag) {
    default: void,
    player: PlayerData,
    plant: PlantData,
    max: void,
};

const PlayerData = struct {};
const PlantData = struct {
    current: []const u8,
    lsystem: lsystem.LindemayerSystem,
};

// entity factory lmfao
pub fn makePlayer(position: calc.v2f) Entity {
    return Entity{
        .position = position,
        .tag = .player,
        .data = .{
            .player = PlayerData{},
        },
    };
}

pub fn makeLindenmayerPlant(position: calc.v2f, current: []const u8) Entity {
    return Entity{
        .position = position,
        .tag = .plant,
        .data = .{
            .plant = .{
                .current = current,
                .lsystem = lsystem.BallsLSystem,
            },
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
    .{ .tag = EntityTag.plant, .tick = plantTick, .draw = plantDraw },
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

    const st = struct {
        var value: i32 = 0;
    };

    if (game.input.skip_intro == .pressed) {
        var min_dist = std.math.floatMax(f32);
        var closest_plant: ?*Entity = null;
        for (game.gameplay_data.entities.items) |*entity| {
            if (entity.tag == .plant) {
                const sqr_dist = entity.position.sqrDistance(self.position);
                if (sqr_dist < 500.0 and sqr_dist < min_dist) {
                    closest_plant = entity;
                    min_dist = sqr_dist;
                }
            }
        }
        if (closest_plant) |plant| {
            std.log.debug("grew plant: {}", .{st.value});
            plant.plant_step_system(game, st.value != 0);
            st.value += 1;
        }
    }

    game.rendering.game_camera.target = @bitCast(self.position.round());
}

fn playerDraw(self: *Entity, game: *gameState.State) void {
    const tex = game.texture_bank.get_tex(gameState.TextureId.player);
    rl.drawTexture(
        tex,
        @as(i32, @intFromFloat(@round(self.position.x))) - @divTrunc(tex.width, 2),
        @as(i32, @intFromFloat(@round(self.position.y))) - @divTrunc(tex.height, 2),
        rl.Color.white,
    );
}

fn plantTick(_: *Entity, _: *gameState.State) void {
    // if (game.input.skip_intro == .pressed) {}
}

fn plantDraw(self: *Entity, game: *gameState.State) void {
    self.data.plant.lsystem.draw(self.data.plant.current, self, game);

    rl.drawRectangle(
        @intFromFloat(@round(self.position.x)),
        @intFromFloat(@round(self.position.y)),
        1,
        1,
        rl.Color.yellow,
    );
}
