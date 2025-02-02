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

const Particle = packed struct {
    x: f32,
    y: f32,
    period: f32,
    padding: f32,
};

const maxParticles = 10000;

pub fn main() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    const shader = rl.LoadShader("res/shaders/default.vert", "res/shaders/default.frag");

    const current_time_loc = rl.GetShaderLocation(shader, "currentTime");
    const color_loc = rl.GetShaderLocation(shader, "color");

    std.debug.print("Size of Particle: {}\n", .{@sizeOf(Particle)});
    std.debug.print("Align of Particle: {}\n", .{@alignOf(Particle)});

    var particles: [maxParticles]Particle = undefined;
    for (0..maxParticles) |i| {
        particles[i].x = @as(f32, @floatFromInt(rl.GetRandomValue(200, gameState.winWidth - 200)));
        particles[i].y = @as(f32, @floatFromInt(rl.GetRandomValue(200, gameState.winHeight - 200)));
        // particles[i].x = @floatFromInt(gameState.winWidth / 2);
        // particles[i].y = @floatFromInt(gameState.winHeight / 2);
        particles[i].period = @as(f32, @floatFromInt(rl.GetRandomValue(10, 30))) * 10.0;
        particles[i].padding = 0.0;
    }
    // std.log.debug("particles: {any}", .{particles});

    const vao = rl.rlLoadVertexArray();
    _ = rl.rlEnableVertexArray(vao);
    const vbo = rl.rlLoadVertexBuffer(&particles[0], maxParticles * 4 * @sizeOf(f32), false);
    // Note: LoadShader() automatically fetches the attribute index of "vertexPosition" and saves it in shader.locs[SHADER_LOC_VERTEX_POSITION]
    rl.rlSetVertexAttribute(@intCast(shader.locs[rl.SHADER_LOC_VERTEX_POSITION]), 4, rl.RL_FLOAT, false, 4 * @sizeOf(f32), 0);
    rl.rlEnableVertexAttribute(0);
    rl.rlDisableVertexBuffer();
    rl.rlDisableVertexArray();

    gl.glEnable(gl.GL_PROGRAM_POINT_SIZE);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.DrawText(rl.TextFormat("%zu particles in one vertex buffer", @as(i32, maxParticles)), 20, 20, 10, rl.RAYWHITE);

        rl.rlDrawRenderBatchActive();

        rl.rlEnableShader(shader.id);

        const time: f32 = @floatCast(rl.GetTime());
        rl.rlSetUniform(current_time_loc, &time, rl.RL_SHADER_UNIFORM_FLOAT, 1);

        const color = rl.ColorNormalize(rl.Color{ .r = 0, .g = 255, .b = 0, .a = 128 });
        rl.rlSetUniform(color_loc, &color.x, rl.RL_SHADER_UNIFORM_VEC4, 1);

        const model_view_projection = rl.MatrixMultiply(rl.rlGetMatrixModelview(), rl.rlGetMatrixProjection());
        rl.rlSetUniformMatrix(shader.locs[rl.SHADER_LOC_MATRIX_MVP], model_view_projection);

        _ = rl.rlEnableVertexArray(vao);
        // rl.rlDrawVertexArray()
        gl.glDrawArrays(gl.GL_POINTS, 0, maxParticles);
        rl.rlDisableVertexArray();

        rl.rlDisableShader();

        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    rl.rlUnloadVertexArray(vao);
    rl.rlUnloadVertexBuffer(vbo);

    rl.CloseWindow();
}
