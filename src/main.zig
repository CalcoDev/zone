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

const resources = @import("resources.zig");

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
    rl.SetTraceLogLevel(rl.LOG_WARNING);

    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    var resource_manager = resources.ResourceManager.create(std.heap.page_allocator);

    var d = {};
    _ = resource_manager.loadResource("scale_curve", .texture, "res/curves/curve.png", @ptrCast(&d));

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

        .animated_velocity = .{},
        .display = .{},
    };
    // ps.init(&resource_manager, std.heap.page_allocator);

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
        if (rl.IsKeyPressed(rl.KEY_F5)) {
            resource_manager.reloadResources();
        }

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

        ps.tick();
        ps.draw();

        rl.EndMode3D();
        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    resource_manager.deinit();

    editor.deinit();

    cimgui.ImGui_ImplOpenGL3_Shutdown();
    cimgui.ImGui_ImplGlfw_Shutdown();
    cimgui.igDestroyContext(imgui_context);

    rl.CloseWindow();
}

const ecs = @import("ecs/ecs.zig");

const Transform = struct {
    pos: calc.v2f,
    rot: f32,
};
const Velocity = calc.v2f;
const RenderablePolygon = struct {
    scale: f32,
    vertices: []calc.v2f,

    pub fn makeTriangle(allocator: std.mem.Allocator, scale: f32) RenderablePolygon {
        const verts = allocator.alloc(calc.v2f, 5) catch unreachable;
        const yshift: f32 = 0.2;
        verts[0] = calc.v2f.init(0, 0.5 + yshift);
        verts[1] = calc.v2f.init(-0.5, -0.5 + yshift);
        verts[2] = calc.v2f.init(-0.25, -0.3 + yshift);
        verts[3] = calc.v2f.init(0.25, -0.3 + yshift);
        verts[4] = calc.v2f.init(0.5, -0.5 + yshift);
        var poly = RenderablePolygon{ .scale = scale, .vertices = verts };
        poly.rotate(-std.math.pi / 2.0);
        return poly;
    }

    pub fn makeCircle(allocator: std.mem.Allocator, segm: usize, scale: f32) RenderablePolygon {
        const verts = allocator.alloc(calc.v2f, segm) catch unreachable;
        for (0..segm) |i| {
            verts[i] = calc.v2f.init_angle(2 * std.math.pi / @as(f32, @floatFromInt(segm)) * @as(f32, @floatFromInt(i)));
        }
        return RenderablePolygon{ .scale = scale, .vertices = verts };
    }

    pub fn rotate(self: *RenderablePolygon, theta: f32) void {
        for (self.vertices) |*v| {
            v.* = v.rotate(theta);
        }
    }
};
const Health = struct {
    health: i32,
};
const Lifetime = struct {
    lifetime: f32,
};

const dt = @as(f32, @floatFromInt(gameState.gameFps));
const playerRotSpeed: f32 = std.math.pi / dt;
const playerFriction: f32 = 0.85;
const playerPropulsion: f32 = 50.0 / dt;

pub fn playerSystem(world: *ecs.World, player: ecs.Entity) void {
    const t = world.getComponent(player, Transform).?;
    const v = world.getComponent(player, Velocity).?;

    const rot_inp: f32 = @floatFromInt(@as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_D))) - @as(i32, @intFromBool(rl.IsKeyDown(rl.KEY_A))));
    t.*.rot += rot_inp * playerRotSpeed;

    if (rl.IsKeyPressed(rl.KEY_SPACE)) {
        const bullet = world.createEntity();
        world.addComponent(bullet, Transform{ .pos = t.pos, .rot = 0 });
        world.addComponent(bullet, Velocity.init_angle(t.rot));
        world.addComponent(bullet, RenderablePolygon.makeCircle(world.allocator, 8, 10));
        world.addComponent(bullet, Lifetime{ .lifetime = 1 });
    }

    if (rl.IsKeyDown(rl.KEY_W)) {
        v.* = v.add(calc.v2f.init_angle(t.rot).scale(playerPropulsion));
    }
    v.* = v.*.scale(playerFriction);
}

pub fn velocityAddSystem(world: *ecs.World) void {
    var view = world.createView(&.{ Transform, Velocity });
    var it = view.getIterator();
    while (it.next()) |entity| {
        const t = world.getComponent(entity, Transform).?;
        const v = world.getComponent(entity, Velocity).?;

        t.*.pos = t.pos.add(v.*);
    }
}

pub fn drawSystem(world: *ecs.World) void {
    var view = world.createView(&.{ Transform, RenderablePolygon });
    var it = view.getIterator();
    while (it.next()) |entity| {
        const t = world.getComponent(entity, Transform).?;
        const rp = world.getComponent(entity, RenderablePolygon).?;

        rl.rlSetLineWidth(2.0);
        rp.rotate(t.rot);
        for (0..rp.vertices.len - 1) |i| {
            const p1: rl.Vector2 = @bitCast(t.pos.add(rp.vertices[i].scale(rp.scale)));
            const p2: rl.Vector2 = @bitCast(t.pos.add(rp.vertices[i + 1].scale(rp.scale)));
            rl.DrawLineV(p1, p2, rl.RED);
        }
        const p1: rl.Vector2 = @bitCast(t.pos.add(rp.vertices[rp.vertices.len - 1].scale(rp.scale)));
        const p2: rl.Vector2 = @bitCast(t.pos.add(rp.vertices[0].scale(rp.scale)));
        rl.DrawLineV(p1, p2, rl.RED);
        rp.rotate(-t.rot);
    }
}

pub fn ecsMain() !void {
    rl.SetTraceLogLevel(rl.LOG_WARNING);

    rl.InitWindow(gameState.winWidth, gameState.winHeight, gameState.winTitle);
    rl.SetTargetFPS(gameState.gameFps);

    var world = ecs.World.init(std.heap.page_allocator);
    const player = world.createEntity();
    world.addComponent(player, Transform{ .pos = calc.v2f.zero(), .rot = 0 });
    world.addComponent(player, Velocity.init(0, 0));
    world.addComponent(player, Health{ .health = 100 });
    world.addComponent(player, RenderablePolygon.makeTriangle(std.heap.page_allocator, 60));

    const camera = rl.Camera3D{
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

    while (!rl.WindowShouldClose()) {
        cimgui.ImGui_ImplOpenGL3_NewFrame();
        cimgui.ImGui_ImplGlfw_NewFrame();
        cimgui.igNewFrame();

        cimgui.igPushFont(iosevka_font);
        // draw imgui stuff maybe
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

        playerSystem(&world, player);
        velocityAddSystem(&world);
        drawSystem(&world);

        rl.EndMode3D();
        rl.DrawFPS(20, gameState.winHeight - 20);

        rl.EndDrawing();
    }

    world.deinit();

    cimgui.ImGui_ImplOpenGL3_Shutdown();
    cimgui.ImGui_ImplGlfw_Shutdown();
    cimgui.igDestroyContext(imgui_context);

    rl.CloseWindow();
}

const set = @import("ecs/sparse_set.zig");

pub fn main() void {
    // try imguiMain();
    try ecsMain();
}
