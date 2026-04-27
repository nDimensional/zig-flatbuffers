const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const flatbuffers = b.addModule("flatbuffers", .{
        .root_source_file = b.path("src/flatbuffers.zig"),
        .target = target,
        .optimize = optimize,
    });

    const reflection = b.addModule("reflection", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/reflection.zig"),
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
        },
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

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("test/test.zig"),
            .imports = &.{
                .{ .name = "flatbuffers", .module = flatbuffers },
                .{ .name = "reflection", .module = reflection },
            },
        }),
    });

    const run_tests = b.addRunArtifact(tests);

    b.step("test", "run the tests").dependOn(&run_tests.step);

    // Integration tests with flatcc
    const integration_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("test/test_integration.zig"),
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
            .{ .name = "reflection", .module = reflection },
        },
    });

    // Add flatcc runtime C sources
    integration_module.addCSourceFile(.{
        .file = b.path("flatcc/src/runtime/builder.c"),
        .flags = &.{"-std=c11"},
    });
    integration_module.addCSourceFile(.{
        .file = b.path("flatcc/src/runtime/verifier.c"),
        .flags = &.{"-std=c11"},
    });
    integration_module.addCSourceFile(.{
        .file = b.path("flatcc/src/runtime/emitter.c"),
        .flags = &.{"-std=c11"},
    });
    integration_module.addCSourceFile(.{
        .file = b.path("flatcc/src/runtime/refmap.c"),
        .flags = &.{"-std=c11"},
    });

    // Add our C helper wrappers for each schema
    integration_module.addCSourceFile(.{
        .file = b.path("test/simple/flatcc_helpers.c"),
        .flags = &.{"-std=c11"},
    });
    integration_module.addCSourceFile(.{
        .file = b.path("test/monster/flatcc_helpers.c"),
        .flags = &.{"-std=c11"},
    });

    integration_module.link_libc = true;
    integration_module.addIncludePath(b.path("flatcc/include"));
    integration_module.addIncludePath(b.path("flatcc/include/flatcc/reflection"));
    integration_module.addIncludePath(b.path("test"));
    integration_module.addIncludePath(b.path("test/simple/flatcc"));
    integration_module.addIncludePath(b.path("test/monster/flatcc"));
    integration_module.addIncludePath(b.path("test/arrow/flatcc"));

    const integration_tests = b.addTest(.{ .root_module = integration_module });

    const run_integration_tests = b.addRunArtifact(integration_tests);

    b.step("test-integration", "run the integration tests").dependOn(&run_integration_tests.step);
}
