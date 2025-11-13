const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const codegen = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/codegen.zig"),
        }),
    });

    const codegen_run = b.addRunArtifact(codegen);
    if (b.args) |args|
        codegen_run.addArgs(args);

    b.installArtifact(codegen);

    b.step("generate", "generate").dependOn(&codegen_run.step);
}
