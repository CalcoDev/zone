pub const v2i = packed struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn init(x: i32, y: i32) v2i {
        return v2i{ .x = x, .y = y };
    }

    pub fn add(a: v2i, b: v2i) v2i {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn mul(a: v2i, b: v2i) v2i {
        return .{ .x = a.x * b.x, .y = a.y * b.y };
    }

    pub fn scale(a: v2i, b: i32) v2i {
        return .{ .x = a.x * b, .y = a.y * b };
    }

    pub fn to_f32(a: v2i) v2f {
        return v2f{ .x = @floatFromInt(a.x), .y = @floatFromInt(a.y) };
    }
};

pub const v2f = packed struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn init(x: f32, y: f32) v2f {
        return v2f{ .x = x, .y = y };
    }

    pub fn add(a: v2f, b: v2f) v2f {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn mul(a: v2f, b: v2f) v2f {
        return .{ .x = a.x * b.x, .y = a.y * b.y };
    }

    pub fn div(a: v2f, b: v2f) v2f {
        return .{ .x = a.x / b.x, .y = a.y / b.y };
    }

    pub fn scale(a: v2f, b: f32) v2f {
        return .{ .x = a.x * b, .y = a.y * b };
    }

    pub fn sqrLen(v: v2f) f32 {
        return v.x * v.x + v.y * v.y;
    }

    pub fn len(v: v2f) f32 {
        return @sqrt(v.sqrLen());
    }

    pub fn normalize(v: v2f) v2f {
        const llen = v.len();
        if (llen != 0.0) {
            return v.scale(1.0 / llen);
        } else {
            return v2f.init(0, 0);
        }
    }

    pub fn init_angle(angle: f32) v2f {
        return v2f.init(@cos(angle), @sin(angle));
    }

    pub fn to_i32(a: v2f) v2i {
        return v2f{ @intFromFloat(a.x), @intFromFloat(a.y) };
    }
};

pub const rect2f = struct {
    pos: v2f = .{},
    size: v2f = .{},

    pub fn init(x: f32, y: f32, width: f32, height: f32) rect2f {
        return rect2f{
            .pos = v2f.init(x, y),
            .size = v2f.init(width, height),
        };
    }

    pub fn center_pos(inner: rect2f, outer: rect2f) v2f {
        return v2f{
            .x = outer.size.x * 0.5 - inner.size.x * 0.5,
            .y = outer.size.y * 0.5 - inner.size.y * 0.5,
        };
    }
};

pub const rect2i = struct {
    pos: v2i = .{},
    size: v2i = .{},

    pub fn init(x: i32, y: i32, width: i32, height: i32) rect2i {
        return rect2i{
            .pos = v2i.init(x, y),
            .size = v2i.init(width, height),
        };
    }

    pub fn center_pos(inner: rect2i, outer: rect2i) v2i {
        return v2i{
            .x = outer.size.x * 0.5 - inner.size.x * 0.5,
            .y = outer.size.y * 0.5 - inner.size.y * 0.5,
        };
    }
};
