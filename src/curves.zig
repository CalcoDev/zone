const std = @import("std");
const calc = @import("calc.zig");

pub const Curve = struct {
    points: std.ArrayList(CurvePoint),

    pub fn sample(self: *Curve, offset: f32) f32 {
        if (self.points.items.len == 0) {
            return 0;
        }
        if (self.points.items.len == 1) {
            return self.points.items[0].y;
        }

        const i: usize = @intCast(self.getCurveIndex(offset));
        if (i == self.points.items.len - 1) {
            return self.points.items[i].y;
        }

        var local = offset - self.points.items[i].x;
        if (i == 0 and local <= 0) {
            return self.points.items[0].y;
        }

        const a = self.points.items[i];
        const b = self.points.items[i + 1];

        var d = b.x - a.x;
        if (@abs(d) < 0.0001) {
            return b.y;
        }
        local /= d;
        d /= 3.0;
        const yac = a.y + d * a.tan_right;
        const ybc = b.y - d * b.tan_left;

        return calc.bezierInterpolate(a.y, yac, ybc, b.y, local);
    }

    fn getCurveIndex(self: *Curve, offset: f32) i32 {
        var imin: usize = 0;
        var imax: usize = self.points.items.len - 1;

        while (imax - imin > 1) {
            const m = (imin + imax) / 2;

            const a = self.points.items[m].x;
            const b = self.points.items[m + 1].x;

            if (a < offset and b < offset) {
                imin = m;
            } else if (a > offset) {
                imax = m;
            } else {
                return @intCast(m);
            }
        }

        if (offset > self.points.items[imax].x) {
            return @intCast(imax);
        }

        return @intCast(imin);
    }
};

pub const CurvePoint = packed struct {
    idx: usize,
    x: f32,
    y: f32,
    tan_left: f32,
    tan_right: f32,

    pub fn to_v2f(self: *const CurvePoint) calc.v2f {
        return calc.v2f.init(self.x, self.y);
    }

    pub fn from_v2f(self: *CurvePoint, v: calc.v2f) void {
        self.x = v.x;
        self.y = v.y;
    }

    pub fn sort(_: void, lhs: CurvePoint, rhs: CurvePoint) bool {
        return lhs.x < rhs.x;
    }
};
