const std = @import("std");

pub fn sign(b: f32) f32 {
    return if (b > 0) 1 else -1;
}

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

    pub fn init_double(v: f32) v2f {
        return init(v, v);
    }

    pub fn add(a: v2f, b: v2f) v2f {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn sub(a: v2f, b: v2f) v2f {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
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

    pub fn can_i32(a: v2f) bool {
        return a.x <= std.math.maxInt(i32) and a.x >= std.math.minInt(i32) and a.y <= std.math.maxInt(i32) and a.y >= std.math.minInt(i32);
    }

    pub fn to_i32(a: v2f) v2i {
        return v2i{ .x = @intFromFloat(a.x), .y = @intFromFloat(a.y) };
    }

    pub fn round(v: v2f) v2f {
        return v2f{ .x = @round(v.x), .y = @round(v.y) };
    }

    pub fn sqrDistance(v1: v2f, v2: v2f) f32 {
        return v2.sub(v1).sqrLen();
    }

    pub fn distance(v1: v2f, v2: v2f) f32 {
        return v2.sub(v1).len();
    }

    pub fn get_angle(v: v2f) f32 {
        return std.math.atan2(v.y, v.x);
    }

    pub fn rotate(self: v2f, theta: f32) v2f {
        const cos_theta = std.math.cos(theta);
        const sin_theta = std.math.sin(theta);
        return v2f{
            .x = self.x * cos_theta - self.y * sin_theta,
            .y = self.x * sin_theta + self.y * cos_theta,
        };
    }

    pub fn clamp(a: v2f, min: v2f, max: v2f) v2f {
        return v2f.init(
            @max(min.x, @min(max.x, a.x)),
            @max(min.y, @min(max.y, a.y)),
        );
    }

    pub fn zero() v2f {
        return v2f.init(0, 0);
    }
};

pub const rect2f = packed struct {
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

pub fn bezierInterpolate(start: f32, c1: f32, c2: f32, end: f32, t: f32) f32 {
    const omt = (1.0 - t);
    const omt2 = omt * omt;
    const omt3 = omt2 * omt;
    const t2 = t * t;
    const t3 = t2 * t;

    return start * omt3 + c1 * omt2 * t * 3.0 + c2 * omt * t2 * 3.0 + end * t3;
}
