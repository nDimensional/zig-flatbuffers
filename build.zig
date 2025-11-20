const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const parse_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/parse.zig"),
    });

    const parse = b.addExecutable(.{
        .name = "parse",
        .root_module = parse_module,
    });

    b.installArtifact(parse);

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
