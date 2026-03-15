const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const zlm = b.dependency("zlm", .{});
    mod.addImport("zlm", zlm.module("zlm"));

    const exe = b.addExecutable(.{
        .name = "opensim",
        .root_module = mod,
    });

    const glfw = buildGLFW(b, target, optimize);
    const jolt = buildJolt(b, target, optimize);
    const imgui = buildImGui(b, target, optimize);
    compileShaders(b, exe);
    const install_shaders = b.addInstallDirectory(.{
        .source_dir = b.path("shaders"),
        .install_dir = .bin,
        .install_subdir = "shaders",
    });
    exe.step.dependOn(&install_shaders.step);

    exe.linkLibrary(glfw);
    exe.linkLibrary(jolt);
    exe.linkLibrary(imgui);
    exe.linkSystemLibrary("vulkan");
    exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

    // miniaudio is a single header — just expose the directory it lives in
    exe.addIncludePath(b.path("libs"));

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
    if (b.args) |args| run_cmd.addArgs(args);

    const exe_test = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(exe_test);
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&run_tests.step);
}
fn buildGLFW(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "glfw",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.addIncludePath(b.path("libs/glfw/include"));
    lib.addIncludePath(b.path("libs/glfw/src"));

    collectCSources(b, lib, "libs/glfw/src", &.{
        "-D_GLFW_X11",
        "-D_GLFW_WAYLAND",
    });

    lib.linkLibC();
    return lib;
}

fn buildJolt(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "Jolt",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.addIncludePath(b.path("libs/JoltPhysics"));
    collectCppSources(b, lib, "libs/JoltPhysics/Jolt", &.{
        "-std=c++17",
        "-DJPH_OBJECT_STREAM",
    });

    lib.linkLibC();
    lib.linkLibCpp();
    return lib;
}

fn buildImGui(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "imgui",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.addIncludePath(b.path("libs/imgui"));
    lib.addIncludePath(b.path("libs/glfw/include")); // needed by imgui_impl_glfw

    lib.addCSourceFiles(.{
        .files = &.{
            "libs/imgui/imgui.cpp",
            "libs/imgui/imgui_draw.cpp",
            "libs/imgui/imgui_tables.cpp",
            "libs/imgui/imgui_widgets.cpp",
            "libs/imgui/backends/imgui_impl_glfw.cpp", // was sdl3, now glfw
            "libs/imgui/backends/imgui_impl_vulkan.cpp",
        },
        .flags = &.{"-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES"},
    });

    lib.linkLibC();
    lib.linkLibCpp();
    return lib;
}

fn compileShaders(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const shaders = [_][2][]const u8{
        .{ "shaders/ui.frag", "shaders/ui.frag.spv" },
        .{ "shaders/ui.vert", "shaders/ui.vert.spv" },
        .{ "shaders/mesh.frag", "shaders/mesh.frag.spv" },
        .{ "shaders/mesh.vert", "shaders/mesh.vert.spv" },
    };

    for (shaders) |shader| {
        const cmd = b.addSystemCommand(&.{
            "glslc",
            shader[0],
            "-o",
            shader[1],
        });
        exe.step.dependOn(&cmd.step);
    }
}

fn collectCppSources(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    path: []const u8,
    flags: []const []const u8,
) void {
    var dir = std.fs.openDirAbsolute(
        b.pathFromRoot(path),
        .{ .iterate = true },
    ) catch return;
    defer dir.close();

    var walker = dir.walk(b.allocator) catch return;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".cpp")) continue;
        lib.addCSourceFile(.{
            .file = b.path(b.pathJoin(&.{ path, entry.path })),
            .flags = flags,
        });
    }
}

fn collectCSources(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    path: []const u8,
    flags: []const []const u8,
) void {
    var dir = std.fs.openDirAbsolute(
        b.pathFromRoot(path),
        .{ .iterate = true },
    ) catch return;
    defer dir.close();

    var walker = dir.walk(b.allocator) catch return;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".c")) continue;
        lib.addCSourceFile(.{
            .file = b.path(b.pathJoin(&.{ path, entry.path })),
            .flags = flags,
        });
    }
}
