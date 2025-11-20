# zig-flatbuffers

**Very WIP.** Currently only supports decoding.

## Overview

This project implements a code generator for efficient FlatBuffers decoders in Zig.

First, a binary `.bfbs` schema file is decoded into an IR defined in `src/types.zig`. The code generator in `src/codegen.zig` then consumes this IR and emits Zig source code containing type definitions and field accessors specific to the given schema. The generated code uses generic functions from a runtime `flatbuffers` module to perform safe, typed, zero-copy access on serialized data.

The repo includes a special pre-generated file, `src/reflection.zig`, which is a decoder for the FlatBuffers reflection schema (`reflection.fbs`, the "schema schema"). This allows the code generator to read `.bfbs` files, creating a bootstrapping loop where the code generator both imports `reflection.zig` and can reproduce it byte-for-byte when run on `reflection.fbs`.

## Usage

### Codegen

First, compile your Flatbuffers schema to a binary `.bfbs` file using the `flatc` CLI (via [homebrew](<[flatbuffers](https://formulae.brew.sh/formula/flatbuffers)>), [Ubuntu](https://packages.ubuntu.com/noble/flatbuffers-compiler), [Debian](https://packages.debian.org/sid/flatbuffers-compiler) etc).

```fbs
// myschema.fbs
enum Fruit : byte { Banana = -1, Orange = 42 }

table FooBar {
    meal      : Fruit = Banana;
    density   : long (deprecated);
    say       : string;
    height    : short;
}
```

```
flatc -b --schema --bfbs-comments --bfbs-builtins myschema.fbs
```

Then generate a Zig decoder library for your schema with

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
// root: myschema.FooBar
```

The result `root: myschema.FooBar` is a _table reference_, a lightweight pointer to an offset within `data` with accessor methods for all of the table fields from your schema.

```zig
const meal = root.meal();
// meal: myschema.Fruit (a real Zig enum type!)

const say = root.say();
// say: [:0]const u8 (a regular slice into the original data buffer)

const height = root.height();
// height: u16 (a regular Zig integer value)
```
