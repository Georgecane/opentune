const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const api = b.createModule(.{
        .root_source_file = b.path("src/opentune.zig"),
        .target = target,
        .optimize = optimize,
    });

    const library = b.addLibrary(.{
        .name = "opentune",
        .linkage = .static,
        .root_module = api,
    });
    b.installArtifact(library);

    const app = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "opentune",
        .root_module = app,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run OpenTune");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = app,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run OpenTune tests");
    test_step.dependOn(&run_tests.step);

    const fmt_step = b.step("fmt", "Format OpenTune source");
    const fmt = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = false,
    });
    fmt_step.dependOn(&fmt.step);
}
