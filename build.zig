const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const codegen_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/codegen.zig"),
    });

    const codegen = b.addExecutable(.{
        .name = "codegen",
        .root_module = codegen_module,
    });

    const codegen_run = b.addRunArtifact(codegen);
    if (b.args) |args|
        codegen_run.addArgs(args);

    b.installArtifact(codegen);
    b.step("generate", "generate").dependOn(&codegen_run.step);

    // example.zig

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("example.zig"),
        }),
    });

    b.installArtifact(example);

    const example_run = b.addRunArtifact(example);
    b.step("run", "run example.zig").dependOn(&example_run.step);

    b.step("check", "Check if example.zig compiles").dependOn(&example.step);
}
