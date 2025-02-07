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

    exe.addIncludePath(b.path("third_party/glad/include"));

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .opengl_version = OpenglVersion.gl_4_3,
    });
    const raylib = raylib_dep.artifact("raylib");
    exe.linkLibrary(raylib);

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
    cimgui.root_module.addCMacro("IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "1");
    cimgui.root_module.addCMacro("IMGUI_DISABLE_OBSOLETE_KEYIO", "1");
    cimgui.root_module.addCMacro("IMGUI_IMPL_API", "extern \"C\"");
    // cimgui.root_module.addCMacro("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "1");
    cimgui.root_module.addCMacro("CIMGUI_USE_GLFW", "1");
    cimgui.root_module.addCMacro("CIMGUI_USE_OPENGL3", "1");
    cimgui.addIncludePath(b.path("third_party/cimgui/"));
    cimgui.addIncludePath(b.path("third_party/cimgui/imgui/"));
    cimgui.addIncludePath(b.path("third_party/glfw/include/"));
    for (cimgui_sources) |source| {
        cimgui.addCSourceFile(.{
            .file = source,
            .flags = &.{ "-std=c++11", "-fvisibility=hidden" },
        });
    }

    const cimgui_link = b.addStaticLibrary(.{ .name = "cimgui_link", .target = target, .optimize = optimize });
    cimgui_link.addCSourceFile(.{
        .file = b.path("third_party/cimgui_helpers/cimgui_include.c"),
        .flags = &.{},
    });
    cimgui_link.linkLibrary(cimgui);
    cimgui_link.linkLibC();

    exe.addIncludePath(b.path("third_party/cimgui_helpers/"));
    exe.addIncludePath(b.path("third_party/glfw/include/"));
    exe.linkLibrary(cimgui_link);

    // const rlimgui = b.addStaticLibrary(.{
    //     .name = "rlImGui",
    //     .target = target,
    //     .optimize = optimize,
    // });
    // rlimgui.addCSourceFile(.{
    //     .file = b.path("third_party/rlImGui/rlImGui.cpp"),
    //     .flags = &.{"-std=c++11"},
    // });
    // rlimgui.addIncludePath(b.path("third_party/rlImGui/"));
    // rlimgui.addIncludePath(b.path("third_party/cimgui/"));
    // rlimgui.addIncludePath(b.path("third_party/cimgui/imgui/"));
    // rlimgui.linkLibrary(raylib);
    // rlimgui.linkLibrary(cimgui);
    // rlimgui.linkLibCpp();

    // const rlimgui_link = b.addStaticLibrary(.{
    //     .name = "raygui_include",
    //     .target = target,
    //     .optimize = optimize,
    // });
    // rlimgui_link.addCSourceFile(.{
    //     .file = b.path("third_party/cimgui_helpers/cimgui_include.c"),
    //     .flags = &.{"-std=c11"},
    // });
    // rlimgui_link.addIncludePath(b.path("third_party/cimgui/generator/output/"));
    // rlimgui_link.linkLibrary(rlimgui);

    // exe.addIncludePath(b.path("third_party/rlImGui/"));
    // exe.linkLibrary(rlimgui_link);
    // exe.addIncludePath(b.path("third_party/cimgui_helpers/"));
    // exe.addIncludePath(b.path("third_party/cimgui/generator/output/"));

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);
}

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
