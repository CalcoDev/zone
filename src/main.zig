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

pub fn main() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    const shader = rl.LoadShader("res/shaders/rect/rect.vert", "res/shaders/rect/rect.frag");

    // const positions_loc = rl.GetShaderLocation(shader, "positions");

    const instanceCount = 100;
    var positions: [instanceCount]calc.v2f = undefined;
    for (0..instanceCount) |i| {
        positions[i].x = @as(f32, @floatFromInt(rl.GetRandomValue(200, gameState.winWidth - 200) - gameState.winWidth));
        positions[i].y = @as(f32, @floatFromInt(rl.GetRandomValue(200, gameState.winHeight - 200) - gameState.winHeight));
        // positions[i].z = @as(f32, @floatFromInt(rl.GetRandomValue(-100, 100)));
    }

    var points = [_]f32{
        0.0,  50.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0,
        50.0, 50.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0,
        0.0,  0.0,  0.0, 1.0, 0.0, 0.0, 1.0, 1.0,

        0.0,  0.0,  0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
        50.0, 50.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0,
        50.0, 0.0,  0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
    };

    const vao = rl.rlLoadVertexArray();
    _ = rl.rlEnableVertexArray(vao);
    const vbo = rl.rlLoadVertexBuffer(&points, points.len * @sizeOf(f32), false);

    rl.rlEnableVertexBuffer(vbo);
    rl.rlSetVertexAttribute(0, 4, rl.RL_FLOAT, false, 8 * @sizeOf(f32), 0);
    rl.rlEnableVertexAttribute(0);
    rl.rlSetVertexAttribute(1, 4, rl.RL_FLOAT, false, 8 * @sizeOf(f32), 4 * @sizeOf(f32));
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
        rl.UpdateCamera(&camera, rl.CAMERA_FREE);

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);

        // rl.DrawRectangle(0, 0, 100, 100, rl.YELLOW);

        rl.rlDrawRenderBatchActive();

        rl.rlEnableShader(shader.id);

        const model_view_projection = rl.MatrixMultiply(rl.rlGetMatrixModelview(), rl.rlGetMatrixProjection());
        rl.rlSetUniformMatrix(shader.locs[rl.SHADER_LOC_MATRIX_MVP], model_view_projection);

        // rl.rlSetUniform(positions_loc, &positions, rl.SHADER_UNIFORM_FLOAT, instanceCount);
        // gl.glUniform3fv(positions_loc, instanceCount, &positions[0].x);

        _ = rl.rlEnableVertexArray(vao);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
        // gl.glDrawArraysInstanced(gl.GL_TRIANGLES, 0, 6, instanceCount);
        rl.rlDisableVertexArray();

        rl.rlDisableShader();
        rl.EndMode3D();

        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    rl.rlUnloadVertexArray(vao);
    rl.rlUnloadVertexBuffer(vbo);

    rl.CloseWindow();
}
