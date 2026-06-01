//! Build-time helpers for invoking the FlatBuffers schema compiler (`flatc`)
//! without requiring it to be installed on the host.
//!
//! Prebuilt `flatc` binaries published by the upstream FlatBuffers project are
//! declared as lazy package dependencies in build.zig.zon (one per supported
//! host platform). `addFlatc` resolves the right one for the host; when the
//! upstream project publishes no binary for the host platform it transparently
//! falls back to a `flatc` found on the system `PATH`.
//!
//! These helpers are re-exported from `build.zig`, so a consumer that depends on
//! this package can use them from its own `build.zig` via
//! `@import("flatbuffers")`. See `addSchemaModule` for the fully managed
//! build-time codegen path.

const std = @import("std");
const builtin = @import("builtin");

/// The upstream FlatBuffers release that the prebuilt `flatc` binaries pinned in
/// build.zig.zon are taken from.
pub const flatbuffers_version = "25.12.19";

/// Returns the name of the build.zig.zon dependency that provides a prebuilt
/// `flatc` binary for the host platform, or `null` when the upstream project
/// publishes no binary for this OS/arch (in which case callers fall back to a
/// `flatc` on `PATH`).
///
/// The upstream project only ships x86_64 Linux, x86_64/aarch64 macOS, and
/// x86_64 Windows binaries; notably there is no prebuilt for aarch64 Linux.
pub fn flatcDependencyName() ?[]const u8 {
    return switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "flatc-linux-x86_64",
            else => null,
        },
        .macos => switch (builtin.cpu.arch) {
            .aarch64 => "flatc-macos-aarch64",
            .x86_64 => "flatc-macos-x86_64",
            else => null,
        },
        .windows => switch (builtin.cpu.arch) {
            .x86_64 => "flatc-windows-x86_64",
            else => null,
        },
        else => null,
    };
}

fn flatcBasename() []const u8 {
    return if (builtin.os.tag == .windows) "flatc.exe" else "flatc";
}

/// Creates a `std.Build.Step.Run` whose program is `flatc`.
///
/// When a prebuilt binary is published for the host platform it is fetched
/// lazily as a Zig package dependency and used as the program. Otherwise the
/// step runs a `flatc` resolved from the system `PATH`.
///
/// Returns `null` only in the transient case where the prebuilt dependency
/// still needs to be fetched: Zig fetches it and re-runs `build()`, so callers
/// should treat `null` as "skip wiring on this pass" (e.g. `orelse return`).
///
/// Use this from the `build.zig` of the package that declares the `flatc-*`
/// dependencies (i.e. this one). From a downstream consumer's `build.zig`, use
/// `addFlatcOwned` and pass `b.dependency("flatbuffers", .{}).builder` as the
/// owner, since lazy dependencies resolve against the manifest of the builder
/// that owns them.
pub fn addFlatc(b: *std.Build) ?*std.Build.Step.Run {
    return addFlatcOwned(b, b);
}

/// Like `addFlatc`, but resolves the prebuilt `flatc` dependency against
/// `owner` (the builder whose build.zig.zon declares the `flatc-*` deps) while
/// creating the Run step in `b`. This lets a consumer run flatc from a step it
/// owns using a binary provided by the flatbuffers package.
pub fn addFlatcOwned(b: *std.Build, owner: *std.Build) ?*std.Build.Step.Run {
    if (flatcDependencyName()) |name| {
        const dep = owner.lazyDependency(name, .{}) orelse return null;
        const run = std.Build.Step.Run.create(b, "flatc");
        run.addFileArg(dep.path(flatcBasename()));
        return run;
    }

    // No prebuilt binary is published for this host platform; fall back to a
    // `flatc` on PATH.
    return b.addSystemCommand(&.{"flatc"});
}

/// Options for `addSchemaModule`.
pub const SchemaOptions = struct {
    /// Module name / output basename for the generated files (e.g. "myschema").
    name: []const u8,
    /// The `.fbs` schema source file to compile.
    source: std.Build.LazyPath,
    /// Additional `.fbs` files that `source` pulls in via `include "..."`.
    /// `flatc` resolves includes by relative path on its own; listing them here
    /// registers them as inputs so the build re-runs when they change.
    includes: []const std.Build.LazyPath = &.{},
};

/// Fully managed build-time codegen: compiles a `.fbs` schema into a ready to
/// `@import` Zig decoder module by running the whole
/// `flatc` -> `zfbs-parse` -> `zfbs-generate` pipeline inside the build graph.
///
/// `flatbuffers_dep` is this package's dependency handle, i.e. the result of
/// `b.dependency("flatbuffers", .{})` in the caller's `build.zig`. The returned
/// module already imports the `flatbuffers` runtime module, so it can be added
/// directly to a compile step:
///
/// ```zig
/// const fb = b.dependency("flatbuffers", .{});
/// const schema = fb.module("flatbuffers"); // not needed directly; shown for context
/// const myschema = @import("flatbuffers").addSchemaModule(b, fb, .{
///     .name = "myschema",
///     .source = b.path("schemas/myschema.fbs"),
/// }) orelse return; // null while the prebuilt flatc is being fetched
/// exe.root_module.addImport("myschema", myschema);
/// ```
///
/// Nothing is written to the source tree and no local `flatc` install is
/// required. Returns `null` while the prebuilt `flatc` dependency is still being
/// fetched (see `addFlatc`).
pub fn addSchemaModule(
    b: *std.Build,
    flatbuffers_dep: *std.Build.Dependency,
    options: SchemaOptions,
) ?*std.Build.Module {
    // Host-side codegen tools, built from this package's exposed modules.
    const parse_exe = b.addExecutable(.{
        .name = "zfbs-parse",
        .root_module = flatbuffers_dep.module("parse"),
    });
    const generate_exe = b.addExecutable(.{
        .name = "zfbs-generate",
        .root_module = flatbuffers_dep.module("generate"),
    });

    return addSchemaModuleFrom(
        b,
        flatbuffers_dep.builder,
        flatbuffers_dep.module("flatbuffers"),
        parse_exe,
        generate_exe,
        options,
    );
}

/// Lower-level variant of `addSchemaModule` that takes the runtime module and
/// host codegen executables explicitly. Useful when those artifacts are already
/// available (for example when this package dogfoods its own pipeline).
///
/// `owner` is the builder whose build.zig.zon declares the `flatc-*`
/// dependencies — the flatbuffers package's builder. When this package builds
/// itself, that is simply `b`.
pub fn addSchemaModuleFrom(
    b: *std.Build,
    owner: *std.Build,
    flatbuffers_module: *std.Build.Module,
    parse_exe: *std.Build.Step.Compile,
    generate_exe: *std.Build.Step.Compile,
    options: SchemaOptions,
) ?*std.Build.Module {
    // .fbs -> .bfbs (via flatc, fetched as a build dependency)
    const flatc_run = addFlatcOwned(b, owner) orelse return null;
    flatc_run.addArgs(&.{ "-b", "--schema", "--bfbs-comments", "--bfbs-builtins" });
    flatc_run.addArg("-o");
    const out_dir = flatc_run.addOutputDirectoryArg("flatc-out");
    flatc_run.addFileArg(options.source);
    for (options.includes) |inc|
        flatc_run.addFileInput(inc);

    // flatc names the output after the source file, replacing `.fbs` with
    // `.bfbs`, regardless of `options.name`.
    const src_base = lazyPathBasename(options.source);
    const src_stem = src_base[0 .. std.mem.lastIndexOfScalar(u8, src_base, '.') orelse src_base.len];
    const bfbs = out_dir.path(b, b.fmt("{s}.bfbs", .{src_stem}));

    // .bfbs -> .zon
    const parse_run = b.addRunArtifact(parse_exe);
    parse_run.addFileArg(bfbs);
    const zon = parse_run.captureStdOut(.{ .basename = b.fmt("{s}.zon", .{options.name}) });

    // .zon -> .zig
    const generate_run = b.addRunArtifact(generate_exe);
    generate_run.addFileArg(zon);
    const zig_src = generate_run.captureStdOut(.{ .basename = b.fmt("{s}.zig", .{options.name}) });

    // The generated `.zig` does `@import("<name>.zon")` by relative path, so the
    // two files must live in the same directory.
    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(zon, b.fmt("{s}.zon", .{options.name}));
    const zig_path = wf.addCopyFile(zig_src, b.fmt("{s}.zig", .{options.name}));

    return b.createModule(.{
        .root_source_file = zig_path,
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers_module },
        },
    });
}

fn lazyPathBasename(lp: std.Build.LazyPath) []const u8 {
    return std.fs.path.basename(switch (lp) {
        .src_path => |sp| sp.sub_path,
        .cwd_relative => |p| p,
        .generated => |g| g.sub_path,
        .dependency => |d| d.sub_path,
    });
}
