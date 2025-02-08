const std = @import("std");

const rl = @import("../libs/raylib.zig");
const glad = @import("../libs/glad.zig");
const cimgui = @import("../libs/cimgui.zig");

const calc = @import("../calc.zig");
const curves = @import("../curves.zig");

pub const Particle = packed struct {
    position: calc.v2f,
    velocity: calc.v2f,
    lifetime: f32,
    age: f32,
    scale: calc.v2f,
};

pub const DrawOrder = enum(u8) {
    index = 1,
    lifetime,
    reverseLifetime,
};

pub const EmissionShapeTag = enum(u8) {
    point = 1,
    rectangle,
    circle,
    ring,
};

pub const EmissionShape = union(EmissionShapeTag) {
    point: struct {},
    rectangle: struct { extents: calc.v2f },
    circle: struct { radius: f32 },
    ring: struct { inner_radius: f32, outer_radius: f32 },
};

pub const ParticleSystem = struct {
    // TODO(calco): These should become like components or sth yknow
    position: calc.v2f,
    rotation: f32,

    emitting: bool,
    one_shot: bool,
    amount: i32,

    lifetime: f32,
    speed_scale: f32,
    explosiveness: f32,
    randomness: f32,
    // TODO(calco): Figure this out lol
    // seed: f32,
    // interpolate: f32,

    local_coords: bool,
    draw_order: DrawOrder,

    spawn: struct {
        shape: EmissionShape,
        offset: calc.v2f,
        scale: calc.v2f,

        angle_min: f32,
        angle_max: f32,

        // TODO(calco): Add velocity stuff here
    },
    animated_velocity: struct {},
    display: struct {},

    // Private Stuff
    particles: []Particle,
    compute: c_uint, // raylib compute shader.
    ssbo: c_uint,

    shader: rl.Shader,
    vao: c_uint,
    vbo: c_uint,

    dbg_tex: rl.Texture,

    scale_curve_tex: rl.Texture,

    pub fn init(self: *ParticleSystem, allocator: std.mem.Allocator) void {
        self.scale_curve_tex = rl.LoadTexture("res/curves/sample2.png");
        rl.rlTextureParameters(self.scale_curve_tex.id, rl.RL_TEXTURE_MAG_FILTER, glad.GL_LINEAR);
        rl.rlTextureParameters(self.scale_curve_tex.id, rl.RL_TEXTURE_MIN_FILTER, glad.GL_LINEAR);

        self.particles = allocator.alloc(Particle, @intCast(self.amount)) catch unreachable;

        const compute_data = rl.LoadFileText("res/shaders/particles/simulate.glsl");
        const compute_shader = rl.rlCompileShader(compute_data, rl.RL_COMPUTE_SHADER);
        self.compute = rl.rlLoadComputeShaderProgram(compute_shader);
        rl.UnloadFileText(compute_data);

        self.ssbo = rl.rlLoadShaderBuffer(@as(u32, @intCast(self.particles.len)) * @sizeOf(Particle), self.particles.ptr, rl.RL_DYNAMIC_COPY);

        var ppoint = [_]f32{
            0.0,  50.0, 0.0, 0.0, 1.0,
            50.0, 50.0, 0.0, 1.0, 1.0,
            0.0,  0.0,  0.0, 0.0, 0.0,

            0.0,  0.0,  0.0, 0.0, 0.0,
            50.0, 50.0, 0.0, 1.0, 1.0,
            50.0, 0.0,  0.0, 1.0, 0.0,
        };

        self.shader = rl.LoadShader("res/shaders/particles/particles.vert", "res/shaders/particles/particles.frag");

        self.vao = rl.rlLoadVertexArray();
        _ = rl.rlEnableVertexArray(self.vao);
        self.vbo = rl.rlLoadVertexBuffer(&ppoint, ppoint.len * @sizeOf(f32), false);

        rl.rlEnableVertexBuffer(self.vbo);
        const stride = 5 * @sizeOf(f32);
        rl.rlSetVertexAttribute(0, 3, rl.RL_FLOAT, false, stride, 0);
        rl.rlEnableVertexAttribute(0);
        rl.rlSetVertexAttribute(1, 3, rl.RL_FLOAT, false, stride, 3 * @sizeOf(f32));
        rl.rlEnableVertexAttribute(1);

        rl.rlDisableVertexBuffer();
        rl.rlDisableVertexArray();

        self.dbg_tex = rl.LoadTexture("res/player.png");
    }

    pub fn tick(self: *ParticleSystem) void {
        rl.rlEnableShader(self.compute);
        rl.rlSetUniform(0, &rl.GetFrameTime(), rl.SHADER_UNIFORM_FLOAT, 1);

        // rl.rlActiveTextureSlot(0);
        // rl.rlEnableTexture(self.scale_curve_tex.id);
        // const loc = glad.glGetUniformLocation(self.compute, "u_scale_tex");
        glad.glUniform1i(1, 0);
        glad.glActiveTexture(glad.GL_TEXTURE0);
        glad.glBindTexture(glad.GL_TEXTURE_2D, @bitCast(self.scale_curve_tex.id));

        rl.rlBindShaderBuffer(self.ssbo, 0);
        const cnt: i32 = @intFromFloat(@ceil(@as(f32, @floatFromInt(self.particles.len)) / 64.0));
        rl.rlComputeShaderDispatch(@intCast(cnt), 1, 1);
        rl.rlDisableShader();
    }

    pub fn draw(self: *ParticleSystem) void {
        rl.rlDrawRenderBatchActive();
        rl.rlEnableShader(self.shader.id);
        rl.rlBindShaderBuffer(self.ssbo, 0);
        const model_view_projection = rl.MatrixMultiply(rl.rlGetMatrixModelview(), rl.rlGetMatrixProjection());
        rl.rlSetUniformMatrix(0, model_view_projection);

        rl.rlEnableTexture(self.dbg_tex.id);
        _ = rl.rlEnableVertexArray(self.vao);

        glad.glEnable(glad.GL_BLEND);
        glad.glEnable(glad.GL_DEPTH_TEST);
        glad.glDepthMask(glad.GL_FALSE);
        glad.glBlendFunc(glad.GL_SRC_ALPHA, glad.GL_ONE_MINUS_SRC_ALPHA);

        glad.glDrawArraysInstanced(glad.GL_TRIANGLES, 0, 6, self.amount);
        rl.rlDisableVertexArray();
        rl.rlDisableShader();

        rl.DrawTexture(self.scale_curve_tex, 100, 100, rl.WHITE);
    }

    // TODO(calco): SHOULD NOT have to pass an allocator to this lmfao
    pub fn deinit(self: *ParticleSystem, deallocator: std.mem.Allocator) void {
        deallocator.free(self.particles);

        rl.UnloadTexture(self.scale_curve_tex);

        rl.rlUnloadShaderProgram(self.compute);
        rl.rlUnloadShaderBuffer(self.ssbo);
        rl.UnloadShader(self.shader);
        rl.rlUnloadVertexArray(self.vao);
        rl.rlUnloadVertexBuffer(self.vbo);

        rl.UnloadTexture(self.dbg_tex);
    }
};
