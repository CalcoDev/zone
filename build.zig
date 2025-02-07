const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zone",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // RAYLIB
    // Internally builds and links: GLFW, GLAD
    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .opengl_version = OpenglVersion.gl_4_3,
    });
    const raylib = raylib_dep.artifact("raylib");
    exe.linkLibrary(raylib);

    // GLAD
    // Already built by Raylib.
    exe.addIncludePath(b.path("third_party/glad/include/"));

    // GLFW
    // Aready built by Raylb.
    exe.addIncludePath(b.path("third_party/glfw/include/"));

    // IMGUI / CIMGUI
    // We build this as a C++ library, and then use a helper library to
    // actually convert it to C. Scuffed but it'll do for now.
    const cimgui = b.addStaticLibrary(.{
        .name = "cimgui",
        .target = target,
        .optimize = optimize,
    });
    cimgui.linkLibCpp();
    const cimgui_sources: []const std.Build.LazyPath = &.{
        b.path("third_party/cimgui/cimgui.cpp"),
        b.path("third_party/cimgui/imgui/imgui.cpp"),
        b.path("third_party/cimgui/imgui/imgui_demo.cpp"),
        b.path("third_party/cimgui/imgui/imgui_draw.cpp"),
        b.path("third_party/cimgui/imgui/imgui_tables.cpp"),
        b.path("third_party/cimgui/imgui/imgui_widgets.cpp"),
        b.path("third_party/cimgui/imgui/backends/imgui_impl_glfw.cpp"),
        b.path("third_party/cimgui/imgui/backends/imgui_impl_opengl3.cpp"),
    };
    const cimgui_macros: []const [2][]const u8 = &.{
        .{ "IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "1" },
        .{ "IMGUI_DISABLE_OBSOLETE_KEYIO", "1" },
        .{ "IMGUI_IMPL_API", "extern \"C\"" },
        .{ "CIMGUI_USE_GLFW", "1" },
        .{ "CIMGUI_USE_OPENGL3", "1" },
    };
    cimgui.addIncludePath(b.path("third_party/cimgui/"));
    cimgui.addIncludePath(b.path("third_party/cimgui/imgui/"));
    cimgui.addIncludePath(b.path("third_party/glfw/include/"));
    for (cimgui_macros) |macro| {
        cimgui.root_module.addCMacro(macro[0], macro[1]);
    }
    for (cimgui_sources) |source| {
        cimgui.addCSourceFile(.{ .file = source, .flags = &.{ "-std=c++11", "-fvisibility=hidden" } });
    }
    exe.addIncludePath(b.path("third_party/cimgui/"));
    exe.addIncludePath(b.path("third_party/cimgui/generator/output/"));
    exe.linkLibrary(cimgui);

    // Back to zig stuff now
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);
}

// Copied from third_party/raylib/build.zig
pub const OpenglVersion = enum {
    auto,
    gl_1_1,
    gl_2_1,
    gl_3_3,
    gl_4_3,
    gles_2,
    gles_3,

    pub fn toCMacroStr(self: @This()) []const u8 {
        switch (self) {
            .auto => @panic("OpenglVersion.auto cannot be turned into a C macro string"),
            .gl_1_1 => return "GRAPHICS_API_OPENGL_11",
            .gl_2_1 => return "GRAPHICS_API_OPENGL_21",
            .gl_3_3 => return "GRAPHICS_API_OPENGL_33",
            .gl_4_3 => return "GRAPHICS_API_OPENGL_43",
            .gles_2 => return "GRAPHICS_API_OPENGL_ES2",
            .gles_3 => return "GRAPHICS_API_OPENGL_ES3",
        }
    }
};
