const std = @import("std");
const rl = @import("libs/raylib.zig");
const calc = @import("calc.zig");

pub const Curve = struct {
    points: std.ArrayList(CurvePoint),

    pub fn init(allocator: std.mem.Allocator) Curve {
        return .{
            .points = std.ArrayList(CurvePoint).init(allocator),
        };
    }

    // pub fn bake(self: *Curve, filepath: []const u8, resolution: i32, min_value: f32, max_value: f32) bool {
    pub fn bake(self: *Curve, filepath: []const u8, resolution: i32, _: f32, _: f32) bool {
        var data = std.heap.page_allocator.alloc(f32, @intCast(resolution * 4)) catch unreachable;
        for (0..@intCast(resolution)) |i| {
            const x = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(resolution));
            const fofx = self.sample(x);
            // const scaled = std.math.lerp(min_value, max_value, fofx) / 1024.0; // TODO(calco): un hardcode 1024 as max value!
            const scaled = fofx;
            data[i * 4 + 0] = scaled;
            data[i * 4 + 1] = scaled;
            data[i * 4 + 2] = scaled;
            data[i * 4 + 3] = scaled;
        }

        const image = rl.Image{
            .data = data.ptr,
            .width = resolution,
            .height = 1,
            .format = rl.PIXELFORMAT_UNCOMPRESSED_R32G32B32A32,
            .mipmaps = 1,
        };

        const real_path = rl.TextFormat("res/curves/%s", @as([*c]u8, @ptrCast(@constCast(filepath))));
        if (rl.ExportImage(image, real_path)) {
            std.heap.page_allocator.free(data);
            std.log.debug("Succesfully saved image to filepath {s}!", .{filepath});
            return true;
        } else {
            std.heap.page_allocator.free(data);
            std.log.debug("Error sabing image to filepath {s}!", .{filepath});
            return false;
        }
        return false;
    }

    pub fn get_length(self: *Curve) usize {
        return self.points.items.len;
    }

    pub fn get_point(self: *Curve, idx: usize) CurvePoint {
        return self.points.items[idx];
    }

    pub fn sortPoints(self: *Curve, update_indices: bool) bool {
        for (0..self.points.items.len - 1) |i| {
            if (self.points.items[i].x > self.points.items[i + 1].x) {
                std.mem.sort(CurvePoint, self.points.items, {}, CurvePoint.sort);
                if (update_indices) {
                    for (0..self.points.items.len) |ii| {
                        self.points.items[ii].idx = ii;
                    }
                }
                return true;
            }
        }
        return false;
    }

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
