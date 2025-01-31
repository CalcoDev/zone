const calc = @import("calc.zig");
const v2f = calc.v2f;
const v2i = calc.v2i;

const EntityType = enum {
    default,
    player
};

const Entity = struct {
    position: v2f = v2f{0, 0},
    e_type: EntityType = EntityType.default,

    pub fn make_player() Entity {
        return Entity{ .e_type = EntityType.player };
    }
};