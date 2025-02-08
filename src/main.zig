const std = @import("std");

const rl = @import("raylib.zig");

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

const curveEditor = @import("editor/curve_editor.zig");
const curves = @import("curves.zig");

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

pub fn curveEditorMain() !void {
    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    var editor = curveEditor.createCurveEditor();
    editor.data.curve.points = std.ArrayList(curves.CurvePoint).init(std.heap.page_allocator);
    editor.init(&editor.data);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        editor.tick(&editor.data);
        // editor.draw();

        rl.DrawFPS(20, gameState.winHeight - 20);
        rl.EndDrawing();
    }

    editor.deinit(&editor.data);

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

        cimgui.igPushFont(iosevka_font);
        if (demo_open) {
            cimgui.igShowDemoWindow(&demo_open);
        }

        cimgui.igImage(
            tex.id,
            cimgui.ImVec2{ .x = 200, .y = 200 },
            cimgui.ImVec2{ .x = 0, .y = 0 },
            cimgui.ImVec2{ .x = 1, .y = 1 },
            cimgui.ImVec4{ .x = 255, .y = 255, .z = 255, .w = 255 },
            cimgui.ImVec4{ .x = 255, .y = 255, .z = 255, .w = 255 },
        );

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
    try curveEditorMain();
    // try gameMain();
    // try imguiMain();
}
