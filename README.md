# zig-flatbuffers

**Very WIP.**

## Usage

### Codegen

First, compile your Flatbuffers schema to a binary .bfbs file

```
flatc -b --schema --bfbs-comments --bfbs-builtins myschema.fbs
```

Then generate a Zig decoder library for you schema with

```sh
zig build generate -- myschema.bfbs | zig fmt --stdin
```

Alternatively, you can build a standalone executable:

```sh
zig build && ./zig-out/bin/generate myschema.bfbs | zig fmt --stdin
```

Save the output to a file such as `myschema.zig` and check it into your repo.

### Runtime

To use the generated library, you will also have to add the `flatbuffers` module as a runtime dependency.

In build.zig:

```zig
pub fn build(b: *std.Build) void {
    // ...
    const flatbuffers_dep = b.dependency("flatbuffers", .{});
    const flatbuffers = flatbuffers_dep.module("flatbuffers");

    // ...
    const myschema = b.createModule(.{
        // ...
        .root_source_file = b.path("myschema.zig"), // output of `zig build generate`
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
        },
    });

    // now add both `myschema` and `flatbuffers` as imports to your lib/exe
    const lib = b.addModule(.{
        // ...
        .root_source_file = b.path("src/lib.zig"),
        .imports = &.{
            .{ .name = "flatbuffers", .module = flatbuffers },
            .{ .name = "myschema", .module = myschema },
        },
    });
}
```

Then in your code (e.g. `src/lib.zig`)

```zig
const flatbuffers = @import("flatbuffers");
const myschema = @import("myschema");

// ...
// data: []align(8) const u8
const root = try flatbuffers.decodeRoot(myschema.FooBar, data);
```
