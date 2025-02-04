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

    var points = [_]f32{
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
    const vbo = rl.rlLoadVertexBuffer(&points, points.len * @sizeOf(f32), false);

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

pub fn drawLineDotted(x0: i32, y0: i32, x1: i32, y1: i32, segment_size: i32, color: rl.Color) void {
    const dx: f32 = @floatFromInt(x1 - x0);
    const dy: f32 = @floatFromInt(y1 - y0);
    const length = @sqrt(dx * dx + dy * dy);

    if (length == 0) return; // Avoid division by zero

    const stepX = dx / length * @as(f32, @floatFromInt(segment_size * 2));
    const stepY = dy / length * @as(f32, @floatFromInt(segment_size * 2));

    var curX: f32 = @floatFromInt(x0);
    var curY: f32 = @floatFromInt(y0);

    var i: f32 = 0;
    while (i < length) : (i += @floatFromInt(segment_size * 2)) {
        const segmSize: f32 = @floatFromInt(segment_size);
        const nextX: i32 = @intFromFloat(curX + (dx / length * segmSize));
        const nextY: i32 = @intFromFloat(curY + (dy / length * segmSize));

        rl.DrawLine(
            @as(i32, @intFromFloat(curX)),
            @as(i32, @intFromFloat(curY)),
            nextX,
            nextY,
            color,
        );

        curX += stepX;
        curY += stepY;
    }
}
pub fn curveEditorMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    const lineWidth = 2;
    const lineSpacingX = 50;
    const lineSpacingY = 50;

    // a / lineSpacingX *
    const rectSizeX = (gameState.winWidth / 2) / lineSpacingX * lineSpacingX;
    const rectSizeY = (gameState.winHeight / 2) / lineSpacingY * lineSpacingY;

    const lineCountX = rectSizeX / lineSpacingX;
    const lineCountY = rectSizeY / lineSpacingY;

    const lineDots = 20;
    const lineDotsX = rectSizeX / lineDots;
    const lineDotsY = rectSizeY / lineDots * 16 / 9;

    const camera = rl.Camera2D{
        .offset = rl.Vector2{
            .x = gameState.winWidth / 2 - rectSizeX / 2,
            .y = gameState.winHeight / 2 - rectSizeY / 2,
        },
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.BeginMode2D(camera);
        rl.rlSetLineWidth(lineWidth);
        for (0..lineCountY + 1) |y| {
            drawLineDotted(
                0,
                @intCast(y * lineSpacingY),
                rectSizeX,
                @intCast(y * lineSpacingY),
                lineDotsX,
                rl.GRAY,
            );
        }
        for (0..lineCountX + 1) |x| {
            drawLineDotted(
                @intCast(x * lineSpacingX),
                0,
                @intCast(x * lineSpacingX),
                rectSizeY,
                lineDotsY,
                rl.GRAY,
            );
        }
        rl.EndMode2D();

        rl.DrawFPS(20, gameState.winHeight - 20);
        rl.EndDrawing();
    }

    rl.CloseWindow();
}

pub fn main() !void {
    try curveEditorMain();
}
