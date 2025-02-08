const std = @import("std");

const rl = @import("libs/raylib.zig");
const cimgui = @import("libs/cimgui.zig");
const glad = @import("libs/glad.zig");
const glfw = @import("libs/glfw.zig");

const calc = @import("calc.zig");
const gameState = @import("game.zig");
const entities = @import("entities.zig");

const curves = @import("curves.zig");
const curveEditor = @import("editor/curve_editor.zig");

const particles = @import("particles/particles.zig");
const particlesEditor = @import("particles/particles_editor.zig");

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

        glad.glEnable(glad.GL_BLEND);
        glad.glEnable(glad.GL_DEPTH_TEST);
        glad.glDepthMask(glad.GL_FALSE);
        glad.glBlendFunc(glad.GL_SRC_ALPHA, glad.GL_ONE_MINUS_SRC_ALPHA);

        glad.glDrawArraysInstanced(glad.GL_TRIANGLES, 0, 6, instanceCount);
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

pub fn imguiMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    var ps = particles.ParticleSystem{
        .position = calc.v2f.zero(),
        .rotation = 0.0,

        .emitting = true,
        .one_shot = false,
        .amount = 512,

        .lifetime = 2.5,
        .speed_scale = 1.0,
        .explosiveness = 0.0,
        .randomness = 1.0,

        .local_coords = true,
        .draw_order = .index,

        .spawn = .{
            .shape = .{ .point = .{} },
            .offset = calc.v2f.zero(),
            .scale = calc.v2f.one(),
            .angle_min = 0.0,
            .angle_max = std.math.pi / 2.0,
        },
        .animated_velocity = undefined,
        .display = undefined,

        .particles = undefined,
        .compute = undefined,
        .ssbo = undefined,
        .shader = undefined,
        .vao = undefined,
        .vbo = undefined,
        .dbg_tex = undefined,
    };
    ps.init(std.heap.page_allocator);

    var editor = curveEditor.createCurveEditor(std.heap.page_allocator);
    editor.init();

    var camera = rl.Camera3D{
        .projection = rl.CAMERA_ORTHOGRAPHIC,
        .fovy = 1280.0 / 2.0,
        .position = rl.Vector3{ .x = 0.0, .y = 0.0, .z = -10.0 },
        .target = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = rl.Vector3{ .x = 0.0, .y = -1.0, .z = 0.0 },
    };

    const monitor = glfw.glfwGetPrimaryMonitor();
    var x_scale: f32 = 0.0;
    var y_scale: f32 = 0.0;
    glfw.glfwGetMonitorContentScale(monitor, &x_scale, &y_scale);

    const imgui_context = cimgui.igCreateContext(null);
    const io = cimgui.igGetIO();
    io.*.ConfigFlags |= cimgui.ImGuiConfigFlags_ViewportsEnable;

    const style = cimgui.igGetStyle();
    cimgui.igStyleColorsDark(style);
    cimgui.ImGuiStyle_ScaleAllSizes(style, x_scale);
    style.*.WindowRounding = 0.0;
    style.*.Colors[cimgui.ImGuiCol_WindowBg].w = 1.0;

    _ = cimgui.ImGui_ImplGlfw_InitForOpenGL(@ptrCast(rl.CALCO_getGlfwContext()), true);
    _ = cimgui.ImGui_ImplOpenGL3_Init("#version 130");

    const fonts = io.*.Fonts;
    const iosevka_font = cimgui.ImFontAtlas_AddFontFromFileTTF(
        fonts,
        "res/fonts/iosevka_term.ttf",
        @round(16.0 * x_scale),
        null,
        cimgui.ImFontAtlas_GetGlyphRangesDefault(fonts),
    );

    editor.data.axisLabelFontsize *= x_scale;

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

        cimgui.igPushFont(iosevka_font);
        editor.tick();
        editor.draw();
        cimgui.igPopFont();
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

        // TODO(calco): All things should probably tick at the same time and draw later but meh :skull:
        ps.tick();
        ps.draw();

        rl.EndMode3D();
        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    editor.deinit();

    cimgui.ImGui_ImplOpenGL3_Shutdown();
    cimgui.ImGui_ImplGlfw_Shutdown();
    cimgui.igDestroyContext(imgui_context);

    rl.CloseWindow();
}

pub fn main() !void {
    try imguiMain();
}
