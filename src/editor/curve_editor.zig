const std = @import("std");

const rl = @import("../libs/raylib.zig");
const cimgui = @import("../libs/cimgui.zig");

const calc = @import("../calc.zig");
const curves = @import("../curves.zig");
const editor = @import("editor.zig");

fn col(hex: comptime_int) rl.Color {
    return @bitCast(@as(u32, ((hex & 0xFF000000) >> 24) |
        ((hex & 0x00FF0000) >> 8) |
        ((hex & 0x0000FF00) << 8) |
        ((hex & 0x000000FF) << 24)));
}

const padx = 16 * 4;
const pady = 9 * 4;

pub const CurveEditor = editor.Editor(CurveEditorData);

pub const CurveEditorData = struct {
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

    selected_tangent_init_mouse_pos: calc.v2f,

    // viz stuff
    sx: i32,
    sy: i32,
    wx: i32,
    wy: i32,

    axisLineColor: rl.Color,

    axisLabelColor: rl.Color,
    axisLabelFontsize: f32,

    pointSize: i32,
    pointColor: rl.Color,
    selectedPointColor: rl.Color,
    pointHoverOffset: i32,
    pointHoverColor: rl.Color,

    lineColor: rl.Color,
    lineSegmentCnt: i32,

    tangentLength: i32 = 75,
    tangentColour: rl.Color,
    tangentSquareSize: i32,
    tangentSquareColor: rl.Color,

    win_open: bool,
    render_tex: rl.RenderTexture2D,

    imgui_mouse_pos: calc.v2f,
    imgui_mouse_delta: calc.v2f,
    imgui_lmb_pressed: bool,
    imgui_lmb_down: bool,
    imgui_rmb_pressed: bool,
    imgui_rmb_down: bool,

    min_value: f32,
    max_value: f32,
    bake_resolution: i32,

    raylib_font: rl.Font,

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

        self.selected_tangent_init_mouse_pos = calc.v2f.zero();

        // init draw stuff
        // self.sx = gameState.winWidth / 4;
        // self.sy = gameState.winHeight / 4;
        // self.wx = gameState.winWidth / 2;
        // self.wy = gameState.winHeight / 2;

        self.sx = 1280 / 4;
        self.sy = 720 / 4;
        self.wx = 1280 / 2;
        self.wy = 720 / 2;

        self.axisLineColor = col(0x67696b88);

        self.axisLabelColor = col(0xffffffff);
        self.axisLabelFontsize = 20;

        self.pointSize = 10;
        self.pointColor = col(0xffffff99);
        self.selectedPointColor = col(0xff00ffff);
        self.pointHoverOffset = 5;
        self.pointHoverColor = col(0xffffffff);

        self.lineColor = col(0xfffffffff);
        self.lineSegmentCnt = 50;

        self.tangentLength = 75;
        self.tangentColour = col(0xffffffff);
        self.tangentSquareSize = 10;
        self.tangentSquareColor = col(0xffffffff);

        self.win_open = true;
        self.render_tex = rl.LoadRenderTexture(self.wx, self.wy);
        self.imgui_mouse_pos = calc.v2f.init(0, 0);
        self.imgui_mouse_delta = calc.v2f.init(0, 0);
        self.imgui_rmb_down = false;
        self.imgui_rmb_pressed = false;
        self.imgui_lmb_down = false;
        self.imgui_lmb_pressed = false;

        self.bake_resolution = 100;
        self.max_value = 0;
        self.min_value = 1;

        self.raylib_font = rl.LoadFont("res/fonts/iosevka_term.ttf");
    }

    pub fn tick(self: *CurveEditorData) void {
        if (self.win_open) {
            _ = cimgui.igBegin("Curve Editor", &self.win_open, cimgui.ImGuiWindowFlags_None);
            var size = calc.v2f.init(0, 0);
            cimgui.igGetWindowSize(@ptrCast(&size));
            const style = cimgui.igGetStyle();
            const win_padding: calc.v2f = @bitCast(style.*.WindowPadding);
            const frame_padding: calc.v2f = @bitCast(style.*.FramePadding);
            const title_padding = cimgui.igGetTextLineHeight() + frame_padding.y * 2.0;

            const sub = win_padding.add(frame_padding);

            self.sx = 0;
            self.sy = 0;
            self.wx = @intFromFloat(size.x - 2.0 * sub.x);
            // self.wy = @intFromFloat(size.y - 2.0 * sub.y - title_padding);
            self.wy = @intFromFloat(@as(f32, @floatFromInt(self.wx)) * 9.0 / 16.0);
            if (self.wx != self.render_tex.texture.width or self.wy != self.render_tex.texture.height) {
                rl.UnloadRenderTexture(self.render_tex);
                self.render_tex = rl.LoadRenderTexture(self.wx, self.wy);
            }

            self.sx = self.sx + padx;
            self.sy = self.sy + pady;
            self.wx = self.wx - 2 * padx;
            self.wy = self.wy - 2 * pady;

            var mouse_pos: calc.v2f = undefined;
            cimgui.igGetMousePos(@ptrCast(&mouse_pos));
            var win_pos: calc.v2f = undefined;
            cimgui.igGetWindowPos(@ptrCast(&win_pos));

            const scroll = calc.v2f.init(cimgui.igGetScrollX(), cimgui.igGetScrollY());

            const last_pos = self.imgui_mouse_pos;
            self.imgui_mouse_pos = mouse_pos.sub(win_pos).sub(sub).sub(calc.v2f.init(-5, title_padding - 5)).add(scroll);
            self.imgui_mouse_delta = self.imgui_mouse_pos.sub(last_pos);
            self.imgui_lmb_pressed = cimgui.igIsMouseClicked_Bool(cimgui.ImGuiMouseButton_Left, false);
            self.imgui_lmb_down = cimgui.igIsMouseDown_Nil(cimgui.ImGuiMouseButton_Left);
            self.imgui_rmb_pressed = cimgui.igIsMouseClicked_Bool(cimgui.ImGuiMouseButton_Right, false);
            self.imgui_rmb_down = cimgui.igIsMouseDown_Nil(cimgui.ImGuiMouseButton_Right);

            // std.log.debug("{}", .{self.imgui_mouse_delta});
            cimgui.igPushStyleColor_U32(cimgui.ImGuiCol_Button, 0x00000000);
            cimgui.igPushStyleColor_U32(cimgui.ImGuiCol_ButtonActive, 0x00000000);
            cimgui.igPushStyleColor_U32(cimgui.ImGuiCol_ButtonHovered, 0x00000000);
            cimgui.igPushStyleVar_Vec2(cimgui.ImGuiStyleVar_FramePadding, @bitCast(calc.v2f.init(0, 0)));
            cimgui.igPushStyleVar_Float(cimgui.ImGuiStyleVar_FrameBorderSize, 0.0);
            _ = cimgui.igImageButton(
                "I handle this input >:)",
                self.render_tex.texture.id,
                // @bitCast(calc.v2i.init(self.wxpadx, self.wypady).to_f32()),
                @bitCast(calc.v2i.init(self.wx + 2 * padx, self.wy + 2 * pady).to_f32()),
                @bitCast(calc.v2f.init(0, 1)),
                @bitCast(calc.v2f.init(1, 0)),
                .{ .x = 255, .y = 255, .z = 255, .w = 255 },
                .{ .x = 255, .y = 255, .z = 255, .w = 255 },
            );
            cimgui.igPopStyleVar(2);
            cimgui.igPopStyleColor(3);

            _ = cimgui.igSliderFloat("Min Value", &self.min_value, -1024, 1024, "%.3f", cimgui.ImGuiSliderFlags_None);
            _ = cimgui.igSliderFloat("Max Value", &self.max_value, -1024, 1024, "%.3f", cimgui.ImGuiSliderFlags_None);
            _ = cimgui.igInputInt("Bake Resolution", &self.bake_resolution, 1, 2, cimgui.ImGuiInputFlags_None);

            // cimgui.igBeginGroup();
            cimgui.igText("Points (%d): ", self.curve.get_length());
            cimgui.igIndent(10);
            for (self.curve.points.items) |*point| {
                if (cimgui.igTreeNodeEx_Str(rl.TextFormat("Point %d", point.idx), cimgui.ImGuiTreeNodeFlags_None)) {
                    var p = point.to_v2f();
                    if (cimgui.igInputFloat2("Position", @ptrCast(&p), "%.3f", cimgui.ImGuiItemFlags_None)) {
                        point.from_v2f(p);
                    }
                    if (point.idx > 0) {
                        _ = cimgui.igInputFloat("Left Tangent", &point.tan_left, 0.01, 0.05, "%.3f", cimgui.ImGuiItemFlags_None);
                    }
                    if (point.idx < self.curve.get_length() - 1) {
                        _ = cimgui.igInputFloat("Right Tangent", &point.tan_right, 0.01, 0.05, "%.3f", cimgui.ImGuiItemFlags_None);
                    }
                    cimgui.igTreePop();
                }
            }

            if (cimgui.igButton("Bake", @bitCast(calc.v2i.init(self.wx, self.wy).to_f32()))) {
                std.log.debug("clicked button!", .{});
            }

            cimgui.igEnd();
        }

        // Update State
        var hovered_point: i32 = -1;
        var hovered_tangent_point: i32 = -1;
        {
            self.sortPoints();

            // Update mouse state
            {
                self.was_inside = self.inside;
                if (self.imgui_mouse_pos.can_i32()) {
                    const m = self.imgui_mouse_pos.to_i32();
                    self.inside = m.x > self.sx and m.x < self.sx + self.wx and m.y > self.sy and m.y < self.sy + self.wy;
                } else {
                    self.inside = false;
                }
            }

            // Update mouse hovered state
            {
                if ((!self.inside or self.prev_hovered < 0 or !self.was_mouse_down)) {
                    hovered_point = self.mouseHoveredPoint(self.curve.points.items, self.pointSize, -1);
                } else {
                    hovered_point = self.prev_hovered;
                }
                self.prev_hovered = hovered_point;
                self.was_mouse_down = false;
            }

            // Update tangent point states
            if (self.set_tangent_points) {
                if (self.selected_tangent_point < 0 or self.prev_hovered_tangent_point >= 0) {
                    hovered_tangent_point = self.mouseHoveredPoint(&self.tangent_points, self.tangentSquareSize, self.prev_hovered_tangent_point);
                }
                self.prev_hovered_tangent_point = hovered_tangent_point;

                if (hovered_tangent_point >= 0) {
                    if (self.imgui_lmb_pressed) {
                        self.selected_tangent_point = hovered_tangent_point;
                        self.selected_tangent_init_mouse_pos = self.imgui_mouse_pos;
                    }
                }

                if (self.selected_tangent_point >= 0) {
                    if (!self.imgui_lmb_down) {
                        self.tangent_points[@intCast(self.selected_tangent_point)].from_v2f(self.last_stored_real_pos);
                        self.selected_tangent_point = -1;
                    } else if (self.selected_point >= 0) {
                        const po = self.curve.points.items[@intCast(self.selected_point)].to_v2f();
                        const p = &self.tangent_points[@intCast(self.selected_tangent_point)];
                        // const p = self.selected_tangent_init_mouse_pos;

                        self.movePoint(p);

                        const cx = self.sx + @as(i32, @intFromFloat(po.x * @as(f32, @floatFromInt(self.wx))));
                        const cy = self.sy + @as(i32, @intFromFloat(@abs(1.0 - po.y) * @as(f32, @floatFromInt(self.wy))));
                        // TODO(calco): make use of offset to not move delta
                        // const thing = self.selected_tangent_init_mouse_pos.add(self.imgui_mouse_pos.sub(self.selected_tangent_init_mouse_pos));
                        // const cx: i32 = @intFromFloat(self.selected_tangent_init_mouse_pos.x);
                        // const cy: i32 = @intFromFloat(self.selected_tangent_init_mouse_pos.y);
                        const idk = self.imgui_mouse_pos.sub(calc.v2i.init(cx, cy).to_f32());
                        p.tan_left = -idk.y / idk.x;

                        const real_o = calc.v2i.init(
                            self.sx + @as(i32, @intFromFloat(po.x * @as(f32, @floatFromInt(self.wx)))),
                            self.sy + @as(i32, @intFromFloat(@abs(1.0 - po.y) * @as(f32, @floatFromInt(self.wy)))),
                        ).to_f32();
                        const real_p = calc.v2i.init(
                            self.sx + @as(i32, @intFromFloat(p.x * @as(f32, @floatFromInt(self.wx)))),
                            self.sy + @as(i32, @intFromFloat(@abs(1.0 - p.y) * @as(f32, @floatFromInt(self.wy)))),
                        ).to_f32();

                        const new_real_p = real_o.add(real_p.sub(real_o).normalize().mul(calc.v2f.init_double(calc.sign((p.x - po.x) * (@as(f32, @floatFromInt(self.selected_tangent_point)) - 0.5)))).scale(@floatFromInt(self.tangentLength)));

                        const new_p = calc.v2f.init(
                            @max(0, @min(1.0, (new_real_p.x - @as(f32, @floatFromInt(self.sx))) / @as(f32, @floatFromInt(self.wx)))),
                            1.0 - @max(0, @min(1.0, (new_real_p.y - @as(f32, @floatFromInt(self.sy))) / @as(f32, @floatFromInt(self.wy)))),
                        );
                        self.last_stored_real_pos = new_p;
                    }
                }
            }

            // Update selected point states
            if (self.selected_tangent_point < 0 and hovered_point >= 0 and self.prev_hovered >= 0 and self.imgui_lmb_down) {
                self.selected_point = hovered_point;

                const p = self.curve.points.items[@intCast(self.selected_point)];
                const cx = self.sx + @as(i32, @intFromFloat(p.x * @as(f32, @floatFromInt(self.wx)))) - @divTrunc(self.pointSize, 2);
                const cy = self.sy + @as(i32, @intFromFloat((1.0 - p.y) * @as(f32, @floatFromInt(self.wy)))) - @divTrunc(self.pointSize, 2);
                self.tangent_points[0] = self.curvePointFromTangent(cx, cy, p.tan_left, -1);
                self.tangent_points[0].tan_left = p.tan_left;
                self.tangent_points[0].tan_right = p.tan_left;
                self.tangent_points[0].idx = self.curve.points.items.len;
                self.tangent_points[1] = self.curvePointFromTangent(cx, cy, p.tan_right, 1);
                self.tangent_points[1].tan_left = p.tan_right;
                self.tangent_points[1].tan_right = p.tan_right;
                self.tangent_points[1].idx = self.curve.points.items.len;
                self.set_tangent_points = true;

                self.movePoint(&self.curve.points.items[@intCast(self.selected_point)]);
                clampPoint(&self.curve.points.items[@intCast(self.selected_point)]);

                self.was_mouse_down = true;
            } else if (self.selected_tangent_point < 0 and self.inside and hovered_point >= 0 and self.imgui_rmb_pressed) {
                _ = self.curve.points.orderedRemove(@intCast(hovered_point));
                self.selected_point = -1;
                hovered_point = -1;
            } else if (self.selected_point < 0 and self.selected_tangent_point < 0 and self.inside and hovered_point < 0 and self.imgui_lmb_pressed) {
                const x_percentage = @max(0, @min(1.0, (self.imgui_mouse_pos.x - @as(f32, @floatFromInt(self.sx))) / @as(f32, @floatFromInt(self.wx))));
                const y_percentage = @max(0, @min(1.0, (self.imgui_mouse_pos.y - @as(f32, @floatFromInt(self.sy))) / @as(f32, @floatFromInt(self.wy))));
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

            if (self.selected_point >= 0 and self.selected_tangent_point < 0 and self.imgui_lmb_pressed) {
                self.selected_point = -1;
                hovered_point = -1;
            }
        }

        rl.BeginTextureMode(self.render_tex);
        rl.ClearBackground(rl.BLACK);

        // Draw stuff
        {
            self.drawLinesAndLabels();

            const pointCnt = 200;
            for (0..pointCnt - 1) |i| {
                const f1 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(pointCnt));
                const f2 = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(pointCnt));
                const a = 1.0 - self.curve.sample(f1);
                const b = 1.0 - self.curve.sample(f2);
                rl.DrawLineV(
                    @bitCast(calc.v2f.init(f1, a).mul(calc.v2i.init(self.wx, self.wy).to_f32()).add(calc.v2i.init(self.sx, self.sy).to_f32())),
                    @bitCast(calc.v2f.init(f2, b).mul(calc.v2i.init(self.wx, self.wy).to_f32()).add(calc.v2i.init(self.sx, self.sy).to_f32())),
                    self.lineColor,
                );
            }

            for (self.curve.points.items, 0..) |p, i| {
                const cx = self.sx + @as(i32, @intFromFloat(p.x * @as(f32, @floatFromInt(self.wx)))) - @divTrunc(self.pointSize, 2);
                const cy = self.sy + @as(i32, @intFromFloat((1.0 - p.y) * @as(f32, @floatFromInt(self.wy)))) - @divTrunc(self.pointSize, 2);

                if (i == hovered_point) {
                    rl.DrawRectangleLines(
                        cx - self.pointHoverOffset,
                        cy - self.pointHoverOffset,
                        self.pointSize + self.pointHoverOffset * 2,
                        self.pointSize + self.pointHoverOffset * 2,
                        self.pointHoverColor,
                    );
                }

                rl.DrawRectangle(cx, cy, self.pointSize, self.pointSize, if (i == self.selected_point) self.selectedPointColor else self.pointColor);
            }

            if (self.selected_point >= 0) {
                const i: usize = @intCast(self.selected_point);
                self.curve.points.items[i].tan_left = self.tangent_points[0].tan_left;
                self.curve.points.items[i].tan_right = self.tangent_points[1].tan_left;
                const p = self.curve.points.items[i];
                const cx = self.sx + @as(i32, @intFromFloat(p.x * @as(f32, @floatFromInt(self.wx))));
                const cy = self.sy + @as(i32, @intFromFloat((1.0 - p.y) * @as(f32, @floatFromInt(self.wy))));
                if (self.selected_point != 0) {
                    self.drawTangentLine(cx, cy, -1.0, p.tan_left, hovered_tangent_point == 0);
                }
                if (self.selected_point != self.curve.points.items.len - 1) {
                    self.drawTangentLine(cx, cy, 1.0, p.tan_right, hovered_tangent_point == 1);
                }
            }
        }

        rl.EndTextureMode();
    }

    pub fn draw(_: *CurveEditorData) void {}

    pub fn deinit(self: *CurveEditorData) void {
        self.curve.points.deinit();
        rl.UnloadRenderTexture(self.render_tex);
        rl.UnloadFont(self.raylib_font);
    }

    fn sortPoints(self: *CurveEditorData) void {
        const did_change = self.curve.sortPoints(false);
        if (!did_change) {
            return;
        }

        var swapped = false;
        for (0..self.curve.get_length()) |point_idx| {
            const old_index = self.curve.get_point(point_idx).idx;
            self.curve.points.items[point_idx].idx = point_idx;
            if (!swapped and old_index == self.selected_point) {
                swapped = true;
                self.selected_point = @intCast(point_idx);
                if (self.prev_hovered >= 0) {
                    self.prev_hovered = @intCast(point_idx);
                }
            }
        }
    }

    // renderer funcs
    fn drawLinesAndLabels(self: *CurveEditorData) void {
        // draw horizontal axis lines
        const sx = self.sx;
        const sy = self.sy;
        const wx = self.wx;
        const wy = self.wy;
        const l_col = self.axisLineColor;
        const lbl_col = self.axisLabelColor;
        const lbl_fsize: i32 = @intFromFloat(self.axisLabelFontsize);
        rl.DrawLine(sx - padx, sy, sx + wx + padx, sy, l_col);
        rl.DrawLine(sx - padx, sy + @divTrunc(wy, 2), sx + wx + padx, sy + @divTrunc(wy, 2), l_col);
        rl.DrawLine(sx - padx, sy + wy, sx + wx + padx, sy + wy, l_col);

        // draw vertical axis lines
        rl.DrawLine(sx, sy - pady, sx, sy + wy + pady, l_col);
        rl.DrawLine(sx + @divTrunc(wx, 4) * 1, sy - pady, sx + @divTrunc(wx, 4) * 1, sy + wy + pady, l_col);
        rl.DrawLine(sx + @divTrunc(wx, 4) * 2, sy - pady, sx + @divTrunc(wx, 4) * 2, sy + wy + pady, l_col);
        rl.DrawLine(sx + @divTrunc(wx, 4) * 3, sy - pady, sx + @divTrunc(wx, 4) * 3, sy + wy + pady, l_col);
        rl.DrawLine(sx + wx, sy - pady, sx + wx, sy + wy + pady, l_col);

        // draw labels
        const space = 1;
        const lbl_fsizef = self.axisLabelFontsize;
        rl.DrawTextEx(self.raylib_font, "1", @bitCast(((calc.v2i){ .x = sx, .y = sy - lbl_fsize }).to_f32()), lbl_fsizef, space, lbl_col);
        rl.DrawTextEx(self.raylib_font, "0.5", @bitCast(((calc.v2i){ .x = sx, .y = sy + @divTrunc(wy, 2) - lbl_fsize }).to_f32()), lbl_fsizef, space, lbl_col);
        rl.DrawTextEx(self.raylib_font, "0", @bitCast(((calc.v2i){ .x = sx, .y = sy + wy - lbl_fsize }).to_f32()), lbl_fsizef, space, lbl_col);

        rl.DrawTextEx(self.raylib_font, "1", @bitCast(((calc.v2i){ .x = sx + wx, .y = sy + wy }).to_f32()), lbl_fsizef, space, lbl_col);
        rl.DrawTextEx(self.raylib_font, "0.25", @bitCast(((calc.v2i){ .x = sx + @divTrunc(wx, 4) * 1, .y = sy + wy }).to_f32()), lbl_fsizef, space, lbl_col);
        rl.DrawTextEx(self.raylib_font, "0.5", @bitCast(((calc.v2i){ .x = sx + @divTrunc(wx, 4) * 2, .y = sy + wy }).to_f32()), lbl_fsizef, space, lbl_col);
        rl.DrawTextEx(self.raylib_font, "0.75", @bitCast(((calc.v2i){ .x = sx + @divTrunc(wx, 4) * 3, .y = sy + wy }).to_f32()), lbl_fsizef, space, lbl_col);
        rl.DrawTextEx(self.raylib_font, "0", @bitCast(((calc.v2i){ .x = sx, .y = sy + wy }).to_f32()), lbl_fsizef, space, lbl_col);
    }

    fn drawTangentLine(self: *CurveEditorData, cx: i32, cy: i32, len_mult: f32, tan: f32, hovered: bool) void {
        const angle = std.math.atan(tan);
        const v = calc.v2f.init_angle(angle).scale(@as(f32, @floatFromInt(self.tangentLength)) * len_mult).to_i32();
        rl.DrawLine(cx, cy, cx + v.x, cy - v.y, self.tangentColour);

        const half_pp = @divTrunc(self.tangentSquareSize, 2);
        const px: i32 = cx + v.x - half_pp;
        const py: i32 = cy - v.y - half_pp;
        const color = if (!hovered) self.tangentColour else rl.RED;
        rl.DrawRectangleLines(px, py, self.tangentSquareSize, self.tangentSquareSize, color);
    }

    // utils
    fn curvePointFromTangent(self: *CurveEditorData, cx: i32, cy: i32, tan: f32, len_mult: f32) curves.CurvePoint {
        const angle = std.math.atan(tan);
        const v = calc.v2f.init_angle(angle).scale(@as(f32, @floatFromInt(self.tangentLength)) * len_mult).to_i32();

        const half_pp = @divTrunc(self.tangentSquareSize, 2);
        const px: i32 = cx + v.x - half_pp;
        const py: i32 = cy - v.y - half_pp;

        return .{
            .x = @as(f32, @floatFromInt((px + half_pp * 2 - self.sx))) / @as(f32, @floatFromInt(self.wx)),
            .y = 1.0 - @as(f32, @floatFromInt((py + half_pp * 2 - self.sy))) / @as(f32, @floatFromInt(self.wy)),
            .tan_left = 0,
            .tan_right = 0,
            .idx = 0,
        };
    }

    fn mouseHoveredPoint(self: *CurveEditorData, list: []const curves.CurvePoint, point_size: i32, look_for: i32) i32 {
        var found: i32 = -1;
        for (list, 0..) |p, i| {
            const c = calc.v2f.init(
                @as(f32, @floatFromInt(self.sx)) + p.x * @as(f32, @floatFromInt(self.wx)),
                @as(f32, @floatFromInt(self.sy)) + (1.0 - p.y) * @as(f32, @floatFromInt(self.wy)),
            );
            const pp: calc.v2f = @bitCast(self.imgui_mouse_pos);
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

    fn movePoint(self: *CurveEditorData, point: *curves.CurvePoint) void {
        // const delta = rl.GetMouseDelta();
        const delta = self.imgui_mouse_delta;
        point.x += delta.x / @as(f32, @floatFromInt(self.wx));
        point.y -= delta.y / @as(f32, @floatFromInt(self.wy));
    }
};

pub fn createCurveEditor(allocator: std.mem.Allocator) CurveEditor {
    var data: CurveEditorData = undefined;
    data.curve = curves.Curve.init(allocator);
    return .{
        .data = data,
        ._init = CurveEditorData.init,
        ._deinit = CurveEditorData.deinit,
        ._tick = CurveEditorData.tick,
        ._draw = CurveEditorData.draw,
    };
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
