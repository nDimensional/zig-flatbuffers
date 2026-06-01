const std = @import("std");

/// Build-time `flatc` helpers, re-exported so that consumers depending on this
/// package can use them from their own `build.zig` via `@import("flatbuffers")`.
const flatc = @import("flatc.zig");
pub const addFlatc = flatc.addFlatc;
pub const addFlatcOwned = flatc.addFlatcOwned;
pub const addSchemaModule = flatc.addSchemaModule;
pub const addSchemaModuleFrom = flatc.addSchemaModuleFrom;
pub const SchemaOptions = flatc.SchemaOptions;
pub const flatcDependencyName = flatc.flatcDependencyName;
pub const flatbuffers_version = flatc.flatbuffers_version;

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

    const parse_exe = b.addExecutable(.{
        .name = "zfbs-parse",
        .root_module = parse,
    });
    b.installArtifact(parse_exe);

    {
        const run = b.addRunArtifact(parse_exe);
        if (b.args) |args|
            run.addArgs(args);

        b.step("parse", "Parse a .bfbs schema into ZON IR").dependOn(&run.step);
    }

    const generate = b.addModule("generate", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/generate.zig"),
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
        },
    });

    const generate_exe = b.addExecutable(.{
        .name = "zfbs-generate",
        .root_module = generate,
    });
    b.installArtifact(generate_exe);

    {
        const run = b.addRunArtifact(generate_exe);
        if (b.args) |args|
            run.addArgs(args);

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

    // `zig build flatc -- <args>`: run the FlatBuffers schema compiler using a
    // prebuilt binary fetched as a build dependency (no local install required),
    // falling back to `flatc` on PATH for hosts without a published prebuilt.
    {
        const flatc_step = b.step("flatc", "Run flatc, fetched as a build dependency");
        if (flatc.addFlatc(b)) |run| {
            if (b.args) |args| run.addArgs(args);
            flatc_step.dependOn(&run.step);
        }
    }

    // `zig build test-codegen`: dogfoods the fully managed build-time codegen
    // path. It compiles `test/simple/simple.fbs` straight to an importable Zig
    // module via `flatc` (fetched as a build dependency) -> `zfbs-parse` ->
    // `zfbs-generate`, with nothing written to the source tree, then type-checks
    // a small test that imports the generated decoder. This exercises the exact
    // pipeline `addSchemaModule` runs for downstream consumers.
    {
        const codegen_step = b.step("test-codegen", "Managed build-time codegen smoke test");
        if (flatc.addSchemaModuleFrom(b, b, flatbuffers, parse_exe, generate_exe, .{
            .name = "simple",
            .source = b.path("test/simple/simple.fbs"),
        })) |simple_module| {
            const codegen_test = b.addTest(.{
                .root_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                    .root_source_file = b.path("test/codegen.zig"),
                    .imports = &.{
                        .{ .name = "simple", .module = simple_module },
                    },
                }),
            });
            codegen_step.dependOn(&b.addRunArtifact(codegen_test).step);
        }
    }
}
