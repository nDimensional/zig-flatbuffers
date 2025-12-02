const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const flatbuffers = b.addModule("flatbuffers", .{
        .root_source_file = b.path("src/flatbuffers.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parse = b.addModule("parse", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/parse.zig"),
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
        },
    });

    {
        const exe = b.addExecutable(.{
            .name = "zfbs-parse",
            .root_module = parse,
        });

        b.installArtifact(exe);

        const run = b.addRunArtifact(exe);
        if (b.args) |args|
            run.addArgs(args);

        b.installArtifact(exe);
        b.step("parse", "Parse a .bfbs schema into ZON IR").dependOn(&run.step);
    }

    const generate = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/generate.zig"),
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
        },
    });

    {
        const exe = b.addExecutable(.{
            .name = "zfbs-generate",
            .root_module = generate,
        });

        b.installArtifact(exe);

        const run = b.addRunArtifact(exe);
        if (b.args) |args|
            run.addArgs(args);

        b.installArtifact(exe);
        b.step("generate", "Generate a decoder library for the ZON schema").dependOn(&run.step);
    }

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
