const rl = @import("raylib");

// pub const sprPlayer = rl.loadTexture("res/player.png");

pub const calc = @import("calc.zig");
pub const v2f = calc.v2f;
pub const v2i = calc.v2i;

pub const EntityType = enum { default, player };

pub const Entity = struct {
    position: v2f = v2f.init(0, 0),
    e_type: EntityType = EntityType.default,

    pub fn make_player() Entity {
        return Entity{ .e_type = EntityType.player };
    }
};
