const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
    @cInclude("raymath.h");
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
};

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
    rl.DrawLine(cx, cy, cx + v.x, cy + v.y, tangentColour);

    const half_pp = tangentSquareSize / 2;
    const px: i32 = cx + v.x - half_pp;
    const py: i32 = cy + v.y - half_pp;
    const color = if (!hovered) tangentColour else rl.RED;
    rl.DrawRectangleLines(px, py, tangentSquareSize, tangentSquareSize, color);
}

pub fn curvePointFromTangent(cx: i32, cy: i32, tan: f32, len_mult: f32) CurvePoint {
    const angle = std.math.atan(tan);
    const v = calc.v2f.init_angle(angle).scale(tangentLength * len_mult).to_i32();

    const half_pp = tangentSquareSize / 2;
    const px: i32 = cx + v.x - half_pp;
    const py: i32 = cy + v.y - half_pp;

    return .{
        .x = @as(f32, @floatFromInt((px + half_pp * 2 - sx))) / @as(f32, @floatFromInt(wx)),
        .y = 1.0 - @as(f32, @floatFromInt((py + half_pp * 2 - sy))) / @as(f32, @floatFromInt(wy)),
        .tan_left = 0,
        .tan_right = 0,
    };
}

pub fn curveEditorMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    points.append(.{ .x = 0, .y = 0, .tan_left = 0, .tan_right = 0 }) catch unreachable;
    points.append(.{ .x = 1, .y = 1, .tan_left = 0, .tan_right = 0 }) catch unreachable;

    var tangent_points: [2]CurvePoint = undefined;
    var set_tangent_points = false;

    var selected_point: i32 = -1;
    var prev_hovered: i32 = -1;
    var was_mouse_down: bool = false;

    var prev_hovered_tangent_point: i32 = -1;
    var selected_tangent_point: i32 = -1;

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        // update state
        const inside = mouseInsideRect();

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
                    selected_tangent_point = -1;
                } else {
                    const po = points.items[@intCast(selected_point)].to_v2f();
                    const p = &tangent_points[@intCast(selected_tangent_point)];
                    movePoint(p);
                    const new_angle = p.to_v2f().sub(po).get_angle();
                    p.tan_left = std.math.tan(-new_angle);
                }
            }

            {
                const p = tangent_points[0];
                const cx = sx + @as(i32, @intFromFloat(p.x * wx)) - pointSize / 2;
                const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy)) - pointSize / 2;
                rl.DrawRectangle(cx, cy, pointSize, pointSize, rl.RED);
            }
            {
                const p = tangent_points[1];
                const cx = sx + @as(i32, @intFromFloat(p.x * wx)) - pointSize / 2;
                const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy)) - pointSize / 2;
                rl.DrawRectangle(cx, cy, pointSize, pointSize, rl.RED);
            }
        }

        if (selected_tangent_point < 0 and hovered_point >= 0 and prev_hovered >= 0 and rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            selected_point = hovered_point;

            const p = points.items[@intCast(selected_point)];
            const cx = sx + @as(i32, @intFromFloat(p.x * wx)) - pointSize / 2;
            const cy = sy + @as(i32, @intFromFloat((1.0 - p.y) * wy)) - pointSize / 2;
            tangent_points[0] = curvePointFromTangent(cx, cy, p.tan_left, -1);
            tangent_points[1] = curvePointFromTangent(cx, cy, p.tan_right, 1);
            set_tangent_points = true;

            movePoint(&points.items[@intCast(selected_point)]);
            clampPoint(&points.items[@intCast(selected_point)]);
            was_mouse_down = true;
        } else if (selected_tangent_point < 0 and inside and hovered_point >= 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
            _ = points.orderedRemove(@intCast(hovered_point));
        } else if (selected_tangent_point < 0 and inside and hovered_point < 0 and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const x_percentage = @max(0, @min(1.0, (rl.GetMousePosition().x - @as(f32, @floatFromInt(sx))) / @as(f32, @floatFromInt(wx))));
            const y_percentage = @max(0, @min(1.0, (rl.GetMousePosition().y - @as(f32, @floatFromInt(sy))) / @as(f32, @floatFromInt(wy))));
            const point = CurvePoint{
                .x = x_percentage,
                .y = 1.0 - y_percentage,
                .tan_left = 0,
                .tan_right = 0,
            };
            const idx = getPointInsertIndex(x_percentage);
            points.insert(idx, point) catch unreachable;
            // hovered_point = @intCast(idx);
            // selected_point = @intCast(idx);
        }

        drawLinesAndLabels();

        for (0..points.items.len - 1) |idx| {
            drawHermiteCurve(points.items[idx], points.items[idx + 1], lineSegmentCnt, lineColor);
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
            if (selected_tangent_point >= 0) {
                points.items[i].tan_left = tangent_points[@intCast(1 - selected_tangent_point)].tan_left;
                points.items[i].tan_right = tangent_points[@intCast(selected_tangent_point)].tan_left;
            }
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

pub fn main() !void {
    try curveEditorMain();
}
