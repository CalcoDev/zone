const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
});

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

var game: gameState.State = undefined;

pub fn main() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);
    // rl.setExitKey(rl.KeyboardKey.null);

    const graphics_shader = rl.LoadShader("res/shaders/default.vert", "res/shaders/default.frag");

    const compute_data = rl.LoadFileText("res/shaders/compute.glsl");
    const compute_shader = rl.rlCompileShader(compute_data, rl.RL_COMPUTE_SHADER);
    const compute_program = rl.rlLoadComputeShaderProgram(compute_shader);
    rl.UnloadFileText(compute_data);

    const numbers_ssbo = rl.rlLoadShaderBuffer(@sizeOf(f32) * 10, null, rl.RL_DYNAMIC_COPY);
    var arr = [_]i32{ 1, 1, 2, 2, 3, 3, 7, 8, 9, 10 };

    const image = rl.GenImageColor(40, 40, rl.WHITE);
    const texture = rl.LoadTextureFromImage(image);

    const vertices = [_]f32{
        -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  0.0, 0.0,
    };
    const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

    rl.rlDisableBackfaceCulling();

    const vao = rl.rlLoadVertexArray();
    _ = rl.rlEnableVertexArray(vao);

    const vbo = rl.rlLoadVertexBuffer(&vertices[0], vertices.len * @sizeOf(f32), false);
    const ebo = rl.rlLoadVertexBufferElement(&indices[0], @sizeOf(i32), false);

    rl.rlSetVertexAttribute(0, 2, rl.RL_FLOAT, false, 4 * @sizeOf(f32), 0);
    rl.rlEnableVertexAttribute(0);
    rl.rlSetVertexAttribute(1, 2, rl.RL_FLOAT, false, 4 * @sizeOf(f32), 2 * @sizeOf(f32));
    rl.rlEnableVertexAttribute(1);

    // const positions = [_]calc.v2f{
    //     calc.v2f.init(50, 50),
    //     calc.v2f.init(100, 100),
    //     calc.v2f.init(200, 200),
    // };
    // const instance_vbo = rl.rlLoadVertexBuffer(&positions[0], positions.len * @sizeOf(calc.v2f), false);
    // rl.rlSetVertexAttribute(2, 2, rl.RL_FLOAT, false, @sizeOf(calc.v2f), 0);
    // rl.rlEnableVertexAttribute(2);
    // rl.rlSetVertexAttributeDivisor(2, 1);

    _ = rl.rlEnableVertexArray(0);

    // game = try gameState.State.init();
    // game.sceneIntro();
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        // const spacing = 20;
        // const xcnt = 10;
        // const ycnt = 10;
        // const xoff = gameState.winWidth / 2 - ycnt * @divTrunc((spacing + texture.width), 2);
        // const yoff = gameState.winHeight / 2 - xcnt * @divTrunc((spacing + texture.height), 2);

        rl.rlSetShader(graphics_shader.id, graphics_shader.locs);

        _ = rl.rlEnableVertexArray(vao);
        rl.rlDrawVertexArray(0, 6);
        // rl.rlDrawVertexArrayElementsInstanced(0, 6, &indices[0], positions.len);
        _ = rl.rlEnableVertexArray(0);

        // for (0..ycnt) |y| {
        //     for (0..xcnt) |x| {
        //         rl.DrawTexture(
        //             texture,
        //             xoff + @as(i32, @intCast(x)) * (texture.width + spacing),
        //             yoff + @as(i32, @intCast(y)) * (texture.height + spacing),
        //             rl.WHITE,
        //         );
        //     }
        // }
        rl.rlSetShader(rl.rlGetShaderIdDefault(), rl.rlGetShaderLocsDefault());

        rl.EndDrawing();

        rl.rlUpdateShaderBuffer(numbers_ssbo, &arr[0], @sizeOf(i32) * 10, 0);
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            rl.rlEnableShader(compute_program);
            rl.rlBindShaderBuffer(numbers_ssbo, 0);
            rl.rlComputeShaderDispatch(1, 1, 1);
            rl.rlDisableShader();
            rl.rlReadShaderBuffer(numbers_ssbo, &arr[0], @sizeOf(i32) * 10, 0);
            std.log.debug("numbers: {any}", .{arr});
        }

        // try game.tick();
        // try game.draw();
    }
    // game.deinit();

    rl.rlUnloadVertexArray(vao);

    rl.rlUnloadVertexBuffer(vbo);
    rl.rlUnloadVertexBuffer(ebo);
    // rl.rlUnloadVertexBuffer(instance_vbo);

    rl.rlUnloadShaderProgram(compute_program);
    rl.rlUnloadShaderBuffer(numbers_ssbo);

    // rl.UnloadMaterial(material);

    rl.UnloadImage(image);
    rl.UnloadTexture(texture);
    rl.UnloadShader(graphics_shader);

    rl.CloseWindow();
}
