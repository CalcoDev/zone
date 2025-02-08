const std = @import("std");
const rl = @import("../raylib.zig");
const calc = @import("../calc.zig");
const curves = @import("../curves.zig");
const editor = @import("editor.zig");

pub const CurveEditorData = struct {
    // const sx = gameState.winWidth / 4;
    // const sy = gameState.winHeight / 4;
    // const wx = gameState.winWidth / 2;
    // const wy = gameState.winHeight / 2;

    // const axisLineColor: rl.Color = col(0x67696b88);

    // const axisLabelColor: rl.Color = col(0xffffffff);
    // const axisLabelFontsize = 20;

    // const pointSize = 10;
    // const pointColor = col(0xffffff99);
    // const selectedPointColor = col(0xff00ffff);
    // const pointHoverOffset = 5;
    // const pointHoverColor = col(0xffffffff);

    // const lineColor = col(0xfffffffff);
    // const lineSegmentCnt = 50;

    // const tangentLength = 75;
    // const tangentColour = col(0xffffffff);
    // const tangentSquareSize = 10;
    // const tangentSquareColor = col(0xffffffff);

    curve: curves.Curve,

    tangent_points: [2]curves.CurvePoint,
    set_tangent_points: bool,

    selected_point: i32,
    prev_hovered: i32,
    was_mouse_down: bool,

    prev_hovered_tangent_point: i32,
    selected_tangent_point: i32,

    last_stored_real_pos: calc.v2f,
    inside: bool,
    was_inside: bool,

    pub fn init(self: *CurveEditorData) void {
        self.curve.points.append(.{ .x = 0, .y = 0, .tan_left = 0.0, .tan_right = 1.0, .idx = 0 }) catch unreachable;
        self.curve.points.append(.{ .x = 0.5, .y = 0.5, .tan_left = 0, .tan_right = 0, .idx = 1 }) catch unreachable;
        self.curve.points.append(.{ .x = 1, .y = 1, .tan_left = 1.0, .tan_right = 0.0, .idx = 2 }) catch unreachable;

        self.tangent_points = undefined;
        self.set_tangent_points = false;

        self.selected_point = -1;
        self.prev_hovered = -1;
        self.was_mouse_down = false;

        self.prev_hovered_tangent_point = -1;
        self.selected_tangent_point = -1;

        self.last_stored_real_pos = calc.v2f.init(0, 0);
        self.inside = false;
        self.was_inside = false;
    }

    pub fn deinit(self: *CurveEditorData) void {
        self.curve.points.deinit();
    }

    pub fn tick(self: *CurveEditorData) void {
        // sort points
        for (0..self.curve.points.items.len - 1) |i| {
            if (self.curve.points.items[i].x > self.curve.points.items[i + 1].x) {
                std.mem.sort(curves.CurvePoint, self.curve.points.items, {}, curves.CurvePoint.sort);
                var didswap = false;
                for (0..self.curve.points.items.len) |ii| {
                    const oldidx = self.curve.points.items[ii].idx;
                    self.curve.points.items[ii].idx = ii;
                    if (!didswap and oldidx == self.selected_point) {
                        didswap = true;
                        self.selected_point = @intCast(ii);
                        if (self.prev_hovered >= 0) {
                            self.prev_hovered = @intCast(ii);
                        }
                    }
                }
                break;
            }
        }

        // thing
        self.was_inside = self.inside;
        {
            const m = @as(calc.v2f, @bitCast(rl.GetMousePosition())).to_i32();
            self.inside = m.x > sx and m.x < sx + wx and m.y > sy and m.y < sy + wy;
        }

        var hovered_point: i32 = -1;
        if ((!self.inside or self.prev_hovered < 0 or !self.was_mouse_down)) {
            hovered_point = mouseHoveredPoint(self.curve.points.items, pointSize, -1);
        } else {
            hovered_point = self.prev_hovered;
        }
        self.prev_hovered = hovered_point;
        self.was_mouse_down = false;

        // more thing
        var hovered_tangent_point: i32 = -1;
        if (self.set_tangent_points) {
            if (self.selected_tangent_point < 0 or self.prev_hovered_tangent_point >= 0) {
                hovered_tangent_point = mouseHoveredPoint(&self.tangent_points, tangentSquareSize, self.prev_hovered_tangent_point);
            }
            self.prev_hovered_tangent_point = hovered_tangent_point;

            if (hovered_tangent_point >= 0) {
                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                    self.selected_tangent_point = hovered_tangent_point;
                }
            }

            if (self.selected_tangent_point >= 0) {
                if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
                    self.tangent_points[@intCast(self.selected_tangent_point)].from_v2f(self.last_stored_real_pos);
                    self.selected_tangent_point = -1;
                } else {
                    const po = self.curve.points.items[@intCast(self.selected_point)].to_v2f();
                    const p = &self.tangent_points[@intCast(self.selected_tangent_point)];

                    movePoint(p);

                    const cx = sx + @as(i32, @intFromFloat(po.x * wx));
                    const cy = sy + @as(i32, @intFromFloat(@abs(1.0 - po.y) * wy));
                    const idk = @as(calc.v2f, @bitCast(rl.GetMousePosition())).sub(calc.v2i.init(cx, cy).to_f32());
                    p.tan_left = -idk.y / idk.x;

                    const real_o = calc.v2i.init(
                        sx + @as(i32, @intFromFloat(po.x * wx)),
                        sy + @as(i32, @intFromFloat(@abs(1.0 - po.y) * wy)),
                    ).to_f32();
                    const real_p = calc.v2i.init(
                        sx + @as(i32, @intFromFloat(p.x * wx)),
                        sy + @as(i32, @intFromFloat(@abs(1.0 - p.y) * wy)),
                    ).to_f32();

                    const new_real_p = real_o.add(real_p.sub(real_o).normalize().mul(calc.v2f.init_double(calc.sign((p.x - po.x) * (@as(f32, @floatFromInt(self.selected_tangent_point)) - 0.5)))).scale(tangentLength));

                    const new_p = calc.v2f.init(
                        @max(0, @min(1.0, (new_real_p.x - @as(f32, @floatFromInt(sx))) / @as(f32, @floatFromInt(wx)))),
                        1.0 - @max(0, @min(1.0, (new_real_p.y - @as(f32, @floatFromInt(sy))) / @as(f32, @floatFromInt(wy)))),
                    );
                    self.last_stored_real_pos = new_p;
                }
            }
        }

        if (self.selected_tangent_point < 0 and hovered_point >= 0 and self.prev_hovered >= 0 and rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            self.selected_point = hovered_point;

            const p = self.curve.points.items[@intCast(self.selected_point)];
            const cx = sx + @as(i32, @intFromFloat(p.x * wx)) - pointSize / 2;
            const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy)) - pointSize / 2;
            self.tangent_points[0] = curvePointFromTangent(cx, cy, p.tan_left, -1);
            self.tangent_points[0].tan_left = p.tan_left;
            self.tangent_points[0].tan_right = p.tan_left;
            self.tangent_points[0].idx = self.curve.points.items.len;
            self.tangent_points[1] = curvePointFromTangent(cx, cy, p.tan_right, 1);
            self.tangent_points[1].tan_left = p.tan_right;
            self.tangent_points[1].tan_right = p.tan_right;
            self.tangent_points[1].idx = self.curve.points.items.len;
            self.set_tangent_points = true;

            movePoint(&self.curve.points.items[@intCast(self.selected_point)]);
            clampPoint(&self.curve.points.items[@intCast(self.selected_point)]);

            self.was_mouse_down = true;
        } else if (self.selected_tangent_point < 0 and self.inside and hovered_point >= 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
            _ = self.curve.points.orderedRemove(@intCast(hovered_point));
            self.selected_point = -1;
            hovered_point = -1;
        } else if (self.selected_point < 0 and self.selected_tangent_point < 0 and self.inside and hovered_point < 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const x_percentage = @max(0, @min(1.0, (rl.GetMousePosition().x - @as(f32, @floatFromInt(sx))) / @as(f32, @floatFromInt(wx))));
            const y_percentage = @max(0, @min(1.0, (rl.GetMousePosition().y - @as(f32, @floatFromInt(sy))) / @as(f32, @floatFromInt(wy))));
            const idx = getPointInsertIndex(self.curve, x_percentage);
            const point = curves.CurvePoint{
                .x = x_percentage,
                .y = 1.0 - y_percentage,
                .tan_left = 0,
                .tan_right = 0,
                .idx = idx,
            };
            self.curve.points.insert(idx, point) catch unreachable;
            for (idx + 1..self.curve.points.items.len) |i| {
                self.curve.points.items[i].idx += 1;
            }
        }

        if (self.selected_point >= 0 and self.selected_tangent_point < 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            self.selected_point = -1;
            hovered_point = -1;
        }

        drawLinesAndLabels();

        const pointCnt = 200;
        for (0..pointCnt - 1) |i| {
            const f1 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(pointCnt));
            const f2 = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(pointCnt));
            const a = 1.0 - self.curve.sample(f1);
            const b = 1.0 - self.curve.sample(f2);
            rl.DrawLineV(
                @bitCast(calc.v2f.init(f1, a).mul(calc.v2i.init(wx, wy).to_f32()).add(calc.v2i.init(sx, sy).to_f32())),
                @bitCast(calc.v2f.init(f2, b).mul(calc.v2i.init(wx, wy).to_f32()).add(calc.v2i.init(sx, sy).to_f32())),
                lineColor,
            );
        }

        for (self.curve.points.items, 0..) |p, i| {
            const cx = sx + @as(i32, @intFromFloat(p.x * wx)) - pointSize / 2;
            const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy)) - pointSize / 2;

            if (i == hovered_point) {
                rl.DrawRectangleLines(
                    cx - pointHoverOffset,
                    cy - pointHoverOffset,
                    pointSize + pointHoverOffset * 2,
                    pointSize + pointHoverOffset * 2,
                    pointHoverColor,
                );
            }

            rl.DrawRectangle(cx, cy, pointSize, pointSize, if (i == self.selected_point) selectedPointColor else pointColor);
        }

        if (self.selected_point >= 0) {
            const i: usize = @intCast(self.selected_point);
            self.curve.points.items[i].tan_left = self.tangent_points[0].tan_left;
            self.curve.points.items[i].tan_right = self.tangent_points[1].tan_left;
            const p = self.curve.points.items[i];
            const cx = sx + @as(i32, @intFromFloat(p.x * wx));
            const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy));
            if (self.selected_point != 0) {
                drawTangentLine(cx, cy, -1.0, p.tan_left, hovered_tangent_point == 0);
            }
            if (self.selected_point != self.curve.points.items.len - 1) {
                drawTangentLine(cx, cy, 1.0, p.tan_right, hovered_tangent_point == 1);
            }
        }
    }

    pub fn draw(_: *CurveEditorData) void {}
};
pub const CurveEditor = editor.Editor(CurveEditorData);

pub fn createCurveEditor() CurveEditor {
    const data = undefined;
    return .{
        .data = data,
        .init = CurveEditorData.init,
        .deinit = CurveEditorData.deinit,
        .tick = CurveEditorData.tick,
        .draw = CurveEditorData.draw,
    };
}

pub fn col(hex: comptime_int) rl.Color {
    return @bitCast(@as(u32, ((hex & 0xFF000000) >> 24) |
        ((hex & 0x00FF0000) >> 8) |
        ((hex & 0x0000FF00) << 8) |
        ((hex & 0x000000FF) << 24)));
}

const gameState = @import("../game.zig");
const sx = gameState.winWidth / 4;
const sy = gameState.winHeight / 4;
const wx = gameState.winWidth / 2;
const wy = gameState.winHeight / 2;

const axisLineColor: rl.Color = col(0x67696b88);

const axisLabelColor: rl.Color = col(0xffffffff);
const axisLabelFontsize = 20;

const pointSize = 10;
const pointColor = col(0xffffff99);
const selectedPointColor = col(0xff00ffff);
const pointHoverOffset = 5;
const pointHoverColor = col(0xffffffff);

const lineColor = col(0xfffffffff);
const lineSegmentCnt = 50;

const tangentLength = 75;
const tangentColour = col(0xffffffff);
const tangentSquareSize = 10;
const tangentSquareColor = col(0xffffffff);

fn mouseHoveredPoint(list: []const curves.CurvePoint, point_size: i32, look_for: i32) i32 {
    var found: i32 = -1;
    for (list, 0..) |p, i| {
        const c = calc.v2f.init(
            @as(f32, @floatFromInt(sx)) + p.x * @as(f32, @floatFromInt(wx)),
            @as(f32, @floatFromInt(sy)) + (1.0 - p.y) * @as(f32, @floatFromInt(wy)),
        );
        const pp: calc.v2f = @bitCast(rl.GetMousePosition());
        const ppp = @as(f32, @floatFromInt(point_size)) / 2.0;
        const d = @max(@abs(pp.x - c.x) - ppp, @abs(pp.y - c.y) - ppp);
        if (d <= @as(f32, @floatFromInt(point_size))) {
            if (look_for < 0 or look_for == @as(i32, @intCast(i))) {
                return @intCast(i);
            } else {
                found = @intCast(i);
            }
        }
    }
    return found;
}

fn movePoint(point: *curves.CurvePoint) void {
    const delta = rl.GetMouseDelta();
    point.x += delta.x / @as(f32, @floatFromInt(wx));
    point.y -= delta.y / @as(f32, @floatFromInt(wy));
}

fn clampPoint(point: *curves.CurvePoint) void {
    point.x = @max(0, @min(1, point.x));
    point.y = @max(0, @min(1, point.y));
}

fn getPointInsertIndex(curve: curves.Curve, x: f32) usize {
    return for (curve.points.items, 0..) |p, i| {
        if (p.x > x) {
            break i;
        }
    } else 0;
}

fn drawLinesAndLabels() void {
    // draw horizontal axis lines
    rl.DrawLine(sx, sy, sx + wx, sy, axisLineColor);
    rl.DrawLine(sx, sy + wy / 2, sx + wx, sy + wy / 2, axisLineColor);
    rl.DrawLine(sx, sy + wy, sx + wx, sy + wy, axisLineColor);

    // draw vertical axis lines
    rl.DrawLine(sx, sy, sx, sy + wy, axisLineColor);
    rl.DrawLine(sx + wx / 4 * 1, sy, sx + wx / 4 * 1, sy + wy, axisLineColor);
    rl.DrawLine(sx + wx / 4 * 2, sy, sx + wx / 4 * 2, sy + wy, axisLineColor);
    rl.DrawLine(sx + wx / 4 * 3, sy, sx + wx / 4 * 3, sy + wy, axisLineColor);
    rl.DrawLine(sx + wx, sy, sx + wx, sy + wy, axisLineColor);

    // draw labels
    rl.DrawText("1", sx, sy - axisLabelFontsize, axisLabelFontsize, axisLabelColor);
    rl.DrawText("0.5", sx, sy + wy / 2 - axisLabelFontsize, axisLabelFontsize, axisLabelColor);
    rl.DrawText("0", sx, sy + wy - axisLabelFontsize, axisLabelFontsize, axisLabelColor);

    rl.DrawText("1", sx + wx, sy + wy, axisLabelFontsize, axisLabelColor);
    rl.DrawText("0.25", sx + wx / 4 * 1, sy + wy, axisLabelFontsize, axisLabelColor);
    rl.DrawText("0.5", sx + wx / 4 * 2, sy + wy, axisLabelFontsize, axisLabelColor);
    rl.DrawText("0.75", sx + wx / 4 * 3, sy + wy, axisLabelFontsize, axisLabelColor);
    rl.DrawText("0", sx, sy + wy, axisLabelFontsize, axisLabelColor);
}

fn drawTangentLine(cx: i32, cy: i32, len_mult: f32, tan: f32, hovered: bool) void {
    const angle = std.math.atan(tan);
    const v = calc.v2f.init_angle(angle).scale(tangentLength * len_mult).to_i32();
    rl.DrawLine(cx, cy, cx + v.x, cy - v.y, tangentColour);

    const half_pp = tangentSquareSize / 2;
    const px: i32 = cx + v.x - half_pp;
    const py: i32 = cy - v.y - half_pp;
    const color = if (!hovered) tangentColour else rl.RED;
    rl.DrawRectangleLines(px, py, tangentSquareSize, tangentSquareSize, color);
}

fn curvePointFromTangent(cx: i32, cy: i32, tan: f32, len_mult: f32) curves.CurvePoint {
    const angle = std.math.atan(tan);
    const v = calc.v2f.init_angle(angle).scale(tangentLength * len_mult).to_i32();

    const half_pp = tangentSquareSize / 2;
    const px: i32 = cx + v.x - half_pp;
    const py: i32 = cy - v.y - half_pp;

    return .{
        .x = @as(f32, @floatFromInt((px + half_pp * 2 - sx))) / @as(f32, @floatFromInt(wx)),
        .y = 1.0 - @as(f32, @floatFromInt((py + half_pp * 2 - sy))) / @as(f32, @floatFromInt(wy)),
        .tan_left = 0,
        .tan_right = 0,
        .idx = 0,
    };
}
