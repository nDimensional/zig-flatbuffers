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

    // This is where the interesting part begins.
    // As you can see we are re-defining the same executable but
    // we're binding it to a dedicated build step.
    const codegen_check = b.addExecutable(.{
        .name = "codegen-check",
        .root_module = codegen_module,
    });

    // Finally we add the "check" step which will be detected
    // by ZLS and automatically enable Build-On-Save.
    // If you copy this into your `build.zig`, make sure to rename 'foo'
    const check = b.step("check", "Check if codegen compiles");
    check.dependOn(&codegen_check.step);
}
