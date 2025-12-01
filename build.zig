const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const flatbuffers = b.addModule("flatbuffers", .{
        .root_source_file = b.path("src/flatbuffers.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parse = b.addExecutable(.{
        .name = "zfbs-parse",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/parse.zig"),
            .imports = &.{
                .{ .name = "flatbuffers", .module = flatbuffers },
            },
        }),
    });

    b.installArtifact(parse);

    const parse_run = b.addRunArtifact(parse);
    if (b.args) |args|
        parse_run.addArgs(args);

    b.installArtifact(parse);
    b.step("parse", "Parse a .bfbs schema into ZON IR").dependOn(&parse_run.step);

    const codegen = b.addExecutable(.{
        .name = "generate",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/codegen.zig"),
            .imports = &.{
                .{ .name = "flatbuffers", .module = flatbuffers },
            },
        }),
    });

    b.installArtifact(codegen);

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
            .imports = &.{
                .{ .name = "flatbuffers", .module = flatbuffers },
            },
        }),
    });

    b.installArtifact(example);

    const example_run = b.addRunArtifact(example);
    b.step("run", "run example.zig").dependOn(&example_run.step);

    b.step("check", "Check if example.zig compiles").dependOn(&example.step);
}
