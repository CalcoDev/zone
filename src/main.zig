const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
    @cInclude("raymath.h");
});

const cimgui = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "1");
    @cDefine("CIMGUI_USE_GLFW", "1");
    @cDefine("CIMGUI_USE_OPENGL3", "1");
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
});

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const gl = @cImport({
    @cInclude("glad/glad.h");
});

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

var game: gameState.State = undefined;

pub fn gameMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    const shader = rl.LoadShader("res/shaders/rect/rect.vert", "res/shaders/rect/rect.frag");

    const instanceCount = 100;
    var positions: [instanceCount]rl.Vector3 = undefined;
    var vels: [instanceCount]rl.Vector2 = undefined;
    for (0..instanceCount) |i| {
        positions[i].x = @as(f32, @floatFromInt(rl.GetRandomValue(0, gameState.winWidth) - gameState.winWidth / 2));
        positions[i].y = @as(f32, @floatFromInt(rl.GetRandomValue(0, gameState.winHeight) - gameState.winHeight / 2));
        positions[i].z = 100.0;

        const angle = @as(f32, @floatFromInt(rl.GetRandomValue(0, 314 * 2))) / 100.0;
        vels[i].x = @cos(angle);
        vels[i].y = @sin(angle);
    }

    var ppoint = [_]f32{
        0.0,  50.0, 0.0, 0.0, 1.0,
        50.0, 50.0, 0.0, 1.0, 1.0,
        0.0,  0.0,  0.0, 0.0, 0.0,

        0.0,  0.0,  0.0, 0.0, 0.0,
        50.0, 50.0, 0.0, 1.0, 1.0,
        50.0, 0.0,  0.0, 1.0, 0.0,
    };

    const tex = rl.LoadTexture("res/particle.png");

    const compute_data = rl.LoadFileText("res/shaders/rect/sim.glsl");
    const compute_shader = rl.rlCompileShader(compute_data, rl.RL_COMPUTE_SHADER);
    const compute = rl.rlLoadComputeShaderProgram(compute_shader);
    rl.UnloadFileText(compute_data);

    const pos_ssbo = rl.rlLoadShaderBuffer(positions.len * @sizeOf(rl.Vector3), &positions, rl.RL_DYNAMIC_COPY);
    const vel_ssbo = rl.rlLoadShaderBuffer(vels.len * @sizeOf(rl.Vector3), &vels, rl.RL_DYNAMIC_COPY);

    const vao = rl.rlLoadVertexArray();
    _ = rl.rlEnableVertexArray(vao);
    const vbo = rl.rlLoadVertexBuffer(&ppoint, ppoint.len * @sizeOf(f32), false);

    rl.rlEnableVertexBuffer(vbo);
    const stride = 5 * @sizeOf(f32);
    rl.rlSetVertexAttribute(0, 3, rl.RL_FLOAT, false, stride, 0);
    rl.rlEnableVertexAttribute(0);
    rl.rlSetVertexAttribute(1, 3, rl.RL_FLOAT, false, stride, 3 * @sizeOf(f32));
    rl.rlEnableVertexAttribute(1);

    rl.rlDisableVertexBuffer();
    rl.rlDisableVertexArray();

    var camera = rl.Camera3D{
        .projection = rl.CAMERA_ORTHOGRAPHIC,
        .fovy = 1280.0 / 2.0,
        .position = rl.Vector3{ .x = 0.0, .y = 0.0, .z = -10.0 },
        .target = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = rl.Vector3{ .x = 0.0, .y = -1.0, .z = 0.0 },
    };

    while (!rl.WindowShouldClose()) {
        const movement = calc.v2i.init(
            @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_D))) - @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_A))),
            @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_S))) - @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_W))),
        );
        const vel = movement.to_f32().normalize().scale(gameState.playerSpeed * 4.0);
        camera.position.x = camera.position.x + vel.x;
        camera.position.y = camera.position.y + vel.y;
        camera.target.x = camera.position.x;
        camera.target.y = camera.position.y;

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);

        rl.rlDrawRenderBatchActive();

        rl.rlEnableShader(compute);
        rl.rlBindShaderBuffer(pos_ssbo, 0);
        rl.rlBindShaderBuffer(vel_ssbo, 1);
        rl.rlComputeShaderDispatch(3, 1, 1);
        rl.rlDisableShader();

        rl.rlEnableShader(shader.id);

        rl.rlBindShaderBuffer(pos_ssbo, 0);

        const model_view_projection = rl.MatrixMultiply(rl.rlGetMatrixModelview(), rl.rlGetMatrixProjection());
        rl.rlSetUniformMatrix(0, model_view_projection);
        // gl.glUniform3fv(1, @as(gl.GLsizei, instanceCount), @ptrCast(&positions));

        rl.rlEnableTexture(tex.id);

        _ = rl.rlEnableVertexArray(vao);

        gl.glEnable(gl.GL_BLEND);
        gl.glEnable(gl.GL_DEPTH_TEST);
        gl.glDepthMask(gl.GL_FALSE);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

        gl.glDrawArraysInstanced(gl.GL_TRIANGLES, 0, 6, instanceCount);
        rl.rlDisableVertexArray();

        rl.rlDisableShader();
        rl.EndMode3D();

        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    rl.UnloadTexture(tex);

    rl.rlUnloadShaderProgram(compute);

    rl.rlUnloadShaderBuffer(pos_ssbo);
    rl.rlUnloadShaderBuffer(vel_ssbo);

    rl.rlUnloadVertexArray(vao);
    rl.rlUnloadVertexBuffer(vbo);

    rl.CloseWindow();
}

pub fn col(hex: comptime_int) rl.Color {
    return @bitCast(@as(u32, ((hex & 0xFF000000) >> 24) |
        ((hex & 0x00FF0000) >> 8) |
        ((hex & 0x0000FF00) << 8) |
        ((hex & 0x000000FF) << 24)));
}

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

const CurvePoint = packed struct {
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

fn getCurveIndex(offset: f32) i32 {
    var imin: usize = 0;
    var imax: usize = points.items.len - 1;

    while (imax - imin > 1) {
        const m = (imin + imax) / 2;

        const a = points.items[m].x;
        const b = points.items[m + 1].x;

        if (a < offset and b < offset) {
            imin = m;
        } else if (a > offset) {
            imax = m;
        } else {
            return @intCast(m);
        }
    }

    if (offset > points.items[imax].x) {
        return @intCast(imax);
    }

    return @intCast(imin);
}

fn bezierInterpolate(start: f32, c1: f32, c2: f32, end: f32, t: f32) f32 {
    const omt = (1.0 - t);
    const omt2 = omt * omt;
    const omt3 = omt2 * omt;
    const t2 = t * t;
    const t3 = t2 * t;

    return start * omt3 + c1 * omt2 * t * 3.0 + c2 * omt * t2 * 3.0 + end * t3;
}

fn sampleCurve(offset: f32) f32 {
    if (points.items.len == 0) {
        return 0;
    }
    if (points.items.len == 1) {
        return points.items[0].y;
    }

    const i: usize = @intCast(getCurveIndex(offset));
    if (i == points.items.len - 1) {
        return points.items[i].y;
    }

    var local = offset - points.items[i].x;
    if (i == 0 and local <= 0) {
        return points.items[0].y;
    }

    const a = points.items[i];
    const b = points.items[i + 1];

    var d = b.x - a.x;
    if (@abs(d) < 0.0001) {
        return b.y;
    }
    local /= d;
    d /= 3.0;
    const yac = a.y + d * a.tan_right;
    const ybc = b.y - d * b.tan_left;

    return bezierInterpolate(a.y, yac, ybc, b.y, local);
}

// fn hermiteToBezier(p0: CurvePoint, p1: CurvePoint, scale: rl.Vector2, offset: rl.Vector2) [4]rl.Vector2 {
//     return [4]rl.Vector2{
//         rl.Vector2{ .x = p0.x * scale.x + offset.x, .y = (1.0 - p0.y) * scale.y + offset.y },
//         rl.Vector2{ .x = (p0.x + p0.tan_right / 3.0) * scale.x + offset.x, .y = (1.0 - p0.y) * scale.y + offset.y },
//         rl.Vector2{ .x = (p1.x - p1.tan_left / 3.0) * scale.x + offset.x, .y = (1.0 - p1.y) * scale.y + offset.y },
//         rl.Vector2{ .x = p1.x * scale.x + offset.x, .y = (1.0 - p1.y) * scale.y + offset.y },
//     };
// }

fn hermiteToBezier(p0: CurvePoint, p1: CurvePoint, scale: rl.Vector2, offset: rl.Vector2) [4]rl.Vector2 {
    const p0_pos = rl.Vector2{
        .x = p0.x * scale.x + offset.x,
        .y = (1.0 - p0.y) * scale.y + offset.y,
    };
    const p1_pos = rl.Vector2{
        .x = p1.x * scale.x + offset.x,
        .y = (1.0 - p1.y) * scale.y + offset.y,
    };

    const distance = rl.Vector2Length(rl.Vector2Subtract(p1_pos, p0_pos)) / 3.0;

    const control1 = rl.Vector2{
        .x = p0_pos.x + p0.tan_right * distance,
        .y = p0_pos.y + p0.tan_right * distance,
    };
    const control2 = rl.Vector2{
        .x = p1_pos.x - p1.tan_left * distance,
        .y = p1_pos.y - p1.tan_left * distance,
    };

    return [4]rl.Vector2{ p0_pos, control1, control2, p1_pos };
}

fn drawHermiteAsBezier(p0: CurvePoint, p1: CurvePoint, scale: rl.Vector2, offset: rl.Vector2, color: rl.Color) void {
    const bezierPoints = hermiteToBezier(@bitCast(p0), @bitCast(p1), scale, offset);
    // rl.DrawBezierCubic(bezierPoints[0], bezierPoints[1], bezierPoints[2], bezierPoints[3], color);
    // rl.DrawSplineBezierCubic()
    rl.DrawSplineBezierCubic(&bezierPoints, 4, 2.0, color);
}

pub fn drawHermiteCurve(p0: CurvePoint, p1: CurvePoint, segments: u32, color: rl.Color) void {
    const start_x = p0.x * @as(f32, @floatFromInt(wx)) + @as(f32, @floatFromInt(sx));
    const start_y = (1.0 - p0.y) * @as(f32, @floatFromInt(wy)) + @as(f32, @floatFromInt(sy));
    const end_x = p1.x * @as(f32, @floatFromInt(wx)) + @as(f32, @floatFromInt(sx));
    const end_y = (1.0 - p1.y) * @as(f32, @floatFromInt(wy)) + @as(f32, @floatFromInt(sy));
    const start_tan_x = p0.tan_left * @as(f32, @floatFromInt(wx));
    const start_tan_y = p0.tan_right * @as(f32, @floatFromInt(wy));
    const end_tan_x = p1.tan_left * @as(f32, @floatFromInt(wx));
    const end_tan_y = p1.tan_right * @as(f32, @floatFromInt(wy));
    var prev_x = start_x;
    var prev_y = start_y;
    for (1..segments + 1) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        const t2 = t * t;
        const t3 = t2 * t;
        const h1 = 2.0 * t3 - 3.0 * t2 + 1.0;
        const h2 = -2.0 * t3 + 3.0 * t2;
        const h3 = t3 - 2.0 * t2 + t;
        const h4 = t3 - t2;
        const x = h1 * start_x + h2 * end_x + h3 * start_tan_x + h4 * end_tan_x;
        const y = h1 * start_y + h2 * end_y + h3 * start_tan_y + h4 * end_tan_y;
        rl.DrawLineV(.{ .x = prev_x, .y = prev_y }, .{ .x = x, .y = y }, color);
        prev_x = x;
        prev_y = y;
    }
}

pub fn mouseInsideRect() bool {
    const m = @as(calc.v2f, @bitCast(rl.GetMousePosition())).to_i32();
    return m.x > sx and m.x < sx + wx and m.y > sy and m.y < sy + wy;
}

pub fn mouseHoveredPoint(list: []const CurvePoint, point_size: i32, look_for: i32) i32 {
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

const allocator = std.heap.page_allocator;
var points = std.ArrayList(CurvePoint).init(allocator);

pub fn movePoint(point: *CurvePoint) void {
    const delta = rl.GetMouseDelta();
    point.x += delta.x / @as(f32, @floatFromInt(wx));
    point.y -= delta.y / @as(f32, @floatFromInt(wy));
}

pub fn clampPoint(point: *CurvePoint) void {
    point.x = @max(0, @min(1, point.x));
    point.y = @max(0, @min(1, point.y));
}

pub fn getPointInsertIndex(x: f32) usize {
    return for (points.items, 0..) |p, i| {
        if (p.x > x) {
            break i;
        }
    } else 0;
}

pub fn drawLinesAndLabels() void {
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

pub fn drawTangentLine(cx: i32, cy: i32, len_mult: f32, tan: f32, hovered: bool) void {
    const angle = std.math.atan(tan);
    const v = calc.v2f.init_angle(angle).scale(tangentLength * len_mult).to_i32();
    rl.DrawLine(cx, cy, cx + v.x, cy - v.y, tangentColour);

    const half_pp = tangentSquareSize / 2;
    const px: i32 = cx + v.x - half_pp;
    const py: i32 = cy - v.y - half_pp;
    const color = if (!hovered) tangentColour else rl.RED;
    rl.DrawRectangleLines(px, py, tangentSquareSize, tangentSquareSize, color);
}

pub fn curvePointFromTangent(cx: i32, cy: i32, tan: f32, len_mult: f32) CurvePoint {
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
        .idx = points.items.len,
    };
}

pub fn curveEditorMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    points.append(.{ .x = 0, .y = 0, .tan_left = 0.0, .tan_right = 1.0, .idx = 0 }) catch unreachable;
    points.append(.{ .x = 0.5, .y = 0.5, .tan_left = 0, .tan_right = 0, .idx = 1 }) catch unreachable;
    points.append(.{ .x = 1, .y = 1, .tan_left = 1.0, .tan_right = 0.0, .idx = 2 }) catch unreachable;

    var tangent_points: [2]CurvePoint = undefined;
    var set_tangent_points = false;

    var selected_point: i32 = -1;
    var prev_hovered: i32 = -1;
    var was_mouse_down: bool = false;

    var prev_hovered_tangent_point: i32 = -1;
    var selected_tangent_point: i32 = -1;

    var last_stored_real_pos = calc.v2f.init(0, 0);
    var inside = false;
    var was_inside = false;

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        for (0..points.items.len - 1) |i| {
            if (points.items[i].x > points.items[i + 1].x) {
                std.mem.sort(CurvePoint, points.items, {}, CurvePoint.sort);
                var didswap = false;
                for (0..points.items.len) |ii| {
                    const oldidx = points.items[ii].idx;
                    points.items[ii].idx = ii;
                    if (!didswap and oldidx == selected_point) {
                        didswap = true;
                        selected_point = @intCast(ii);
                        if (prev_hovered >= 0) {
                            prev_hovered = @intCast(ii);
                        }
                    }
                }
                break;
            }
        }

        // update state
        was_inside = inside;
        inside = mouseInsideRect();

        var hovered_point: i32 = -1;
        if ((!inside or prev_hovered < 0 or !was_mouse_down)) {
            hovered_point = mouseHoveredPoint(points.items, pointSize, -1);
        } else {
            hovered_point = prev_hovered;
        }
        prev_hovered = hovered_point;
        was_mouse_down = false;

        var hovered_tangent_point: i32 = -1;
        if (set_tangent_points) {
            if (selected_tangent_point < 0 or prev_hovered_tangent_point >= 0) {
                hovered_tangent_point = mouseHoveredPoint(&tangent_points, tangentSquareSize, prev_hovered_tangent_point);
            }
            prev_hovered_tangent_point = hovered_tangent_point;

            if (hovered_tangent_point >= 0) {
                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                    selected_tangent_point = hovered_tangent_point;
                }
            }

            if (selected_tangent_point >= 0) {
                if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
                    tangent_points[@intCast(selected_tangent_point)].from_v2f(last_stored_real_pos);
                    selected_tangent_point = -1;
                } else {
                    const po = points.items[@intCast(selected_point)].to_v2f();
                    const p = &tangent_points[@intCast(selected_tangent_point)];

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

                    const new_real_p = real_o.add(real_p.sub(real_o).normalize().mul(calc.v2f.init_double(calc.sign((p.x - po.x) * (@as(f32, @floatFromInt(selected_tangent_point)) - 0.5)))).scale(tangentLength));

                    const new_p = calc.v2f.init(
                        @max(0, @min(1.0, (new_real_p.x - @as(f32, @floatFromInt(sx))) / @as(f32, @floatFromInt(wx)))),
                        1.0 - @max(0, @min(1.0, (new_real_p.y - @as(f32, @floatFromInt(sy))) / @as(f32, @floatFromInt(wy)))),
                    );
                    last_stored_real_pos = new_p;
                }
            }
        }

        if (selected_tangent_point < 0 and hovered_point >= 0 and prev_hovered >= 0 and rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            selected_point = hovered_point;

            const p = points.items[@intCast(selected_point)];
            const cx = sx + @as(i32, @intFromFloat(p.x * wx)) - pointSize / 2;
            const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy)) - pointSize / 2;
            tangent_points[0] = curvePointFromTangent(cx, cy, p.tan_left, -1);
            tangent_points[0].tan_left = p.tan_left;
            tangent_points[0].tan_right = p.tan_left;
            tangent_points[1] = curvePointFromTangent(cx, cy, p.tan_right, 1);
            tangent_points[1].tan_left = p.tan_right;
            tangent_points[1].tan_right = p.tan_right;
            set_tangent_points = true;

            movePoint(&points.items[@intCast(selected_point)]);
            clampPoint(&points.items[@intCast(selected_point)]);

            was_mouse_down = true;
        } else if (selected_tangent_point < 0 and inside and hovered_point >= 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
            _ = points.orderedRemove(@intCast(hovered_point));
            selected_point = -1;
            hovered_point = -1;
        } else if (selected_point < 0 and selected_tangent_point < 0 and inside and hovered_point < 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const x_percentage = @max(0, @min(1.0, (rl.GetMousePosition().x - @as(f32, @floatFromInt(sx))) / @as(f32, @floatFromInt(wx))));
            const y_percentage = @max(0, @min(1.0, (rl.GetMousePosition().y - @as(f32, @floatFromInt(sy))) / @as(f32, @floatFromInt(wy))));
            const idx = getPointInsertIndex(x_percentage);
            const point = CurvePoint{
                .x = x_percentage,
                .y = 1.0 - y_percentage,
                .tan_left = 0,
                .tan_right = 0,
                .idx = idx,
            };
            points.insert(idx, point) catch unreachable;
            for (idx + 1..points.items.len) |i| {
                points.items[i].idx += 1;
            }
        }

        if (selected_point >= 0 and selected_tangent_point < 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            selected_point = -1;
            hovered_point = -1;
        }

        drawLinesAndLabels();

        const pointCnt = 200;
        for (0..pointCnt - 1) |i| {
            const f1 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(pointCnt));
            const f2 = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(pointCnt));
            const a = 1.0 - sampleCurve(f1);
            const b = 1.0 - sampleCurve(f2);
            rl.DrawLineV(
                @bitCast(calc.v2f.init(f1, a).mul(calc.v2i.init(wx, wy).to_f32()).add(calc.v2i.init(sx, sy).to_f32())),
                @bitCast(calc.v2f.init(f2, b).mul(calc.v2i.init(wx, wy).to_f32()).add(calc.v2i.init(sx, sy).to_f32())),
                lineColor,
            );
        }

        for (points.items, 0..) |p, i| {
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

            rl.DrawRectangle(cx, cy, pointSize, pointSize, if (i == selected_point) selectedPointColor else pointColor);
        }

        if (selected_point >= 0) {
            const i: usize = @intCast(selected_point);
            points.items[i].tan_left = tangent_points[0].tan_left;
            points.items[i].tan_right = tangent_points[1].tan_left;
            const p = points.items[i];
            const cx = sx + @as(i32, @intFromFloat(p.x * wx));
            const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy));
            if (selected_point != 0) {
                drawTangentLine(cx, cy, -1.0, p.tan_left, hovered_tangent_point == 0);
            }
            if (selected_point != points.items.len - 1) {
                drawTangentLine(cx, cy, 1.0, p.tan_right, hovered_tangent_point == 1);
            }
        }

        rl.DrawFPS(20, gameState.winHeight - 20);
        rl.EndDrawing();
    }

    points.deinit();
    rl.CloseWindow();
}

pub fn imguiMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    var camera = rl.Camera3D{
        .projection = rl.CAMERA_ORTHOGRAPHIC,
        .fovy = 1280.0 / 2.0,
        .position = rl.Vector3{ .x = 0.0, .y = 0.0, .z = -10.0 },
        .target = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = rl.Vector3{ .x = 0.0, .y = -1.0, .z = 0.0 },
    };

    const tex = rl.LoadTexture("res/player.png");

    const imgui_context = cimgui.igCreateContext(null);
    const io = cimgui.igGetIO();
    io.*.ConfigFlags |= cimgui.ImGuiConfigFlags_ViewportsEnable;
    // io.*.ConfigFlags.FontGlobalScale = ...

    const style = cimgui.igGetStyle();
    cimgui.igStyleColorsDark(style);
    style.*.WindowRounding = 0.0;
    style.*.Colors[cimgui.ImGuiCol_WindowBg].w = 1.0;

    _ = cimgui.ImGui_ImplGlfw_InitForOpenGL(@ptrCast(rl.CALCO_getGlfwContext()), true);
    _ = cimgui.ImGui_ImplOpenGL3_Init("#version 130");

    // var wopen = true;
    var demo_open = true;

    while (!rl.WindowShouldClose()) {
        const movement = calc.v2i.init(
            @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_D))) - @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_A))),
            @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_S))) - @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_W))),
        );
        const vel = movement.to_f32().normalize().scale(gameState.playerSpeed * 4.0);
        camera.position.x = camera.position.x + vel.x;
        camera.position.y = camera.position.y + vel.y;
        camera.target.x = camera.position.x;
        camera.target.y = camera.position.y;

        cimgui.ImGui_ImplOpenGL3_NewFrame();
        cimgui.ImGui_ImplGlfw_NewFrame();
        cimgui.igNewFrame();

        if (demo_open) {
            cimgui.igShowDemoWindow(&demo_open);
        }

        cimgui.igRender();

        rl.rlViewport(0, 0, gameState.winWidth, gameState.winHeight);
        rl.rlClearColor(0, 0, 0, 255);
        rl.rlClearScreenBuffers();

        cimgui.ImGui_ImplOpenGL3_RenderDrawData(cimgui.igGetDrawData());

        const backup_context = rl.CALCO_getGlfwContext();
        cimgui.igUpdatePlatformWindows();
        cimgui.igRenderPlatformWindowsDefault(null, null);
        rl.CALCO_setGlfwContext(backup_context);

        rl.BeginDrawing();
        rl.BeginMode3D(camera);
        rl.EndMode3D();
        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    rl.UnloadTexture(tex);

    cimgui.ImGui_ImplOpenGL3_Shutdown();
    cimgui.ImGui_ImplGlfw_Shutdown();
    cimgui.igDestroyContext(imgui_context);

    rl.CloseWindow();
}

pub fn main() !void {
    // try curveEditorMain();
    // try gameMain();
    try imguiMain();
}
