# zig-flatbuffers

Efficient FlatBuffers decoders and encoders for Zig, in Zig.

## Table of Contents

- [Overview](#overview)
- [Usage](#usage)
  - [Codegen](#codegen)
  - [Runtime](#runtime)
    - [Decoding](#decoding)
    - [Building](#building)
- [License](#license)

## Overview

This project implements a code generator that takes a Flatbuffers schema and emits a Zig source file with native Zig types modeling the tables in the schema, as well as a runtime library exporting generic methods for encoding and decoding Flatbuffers data given one of the generated types.

```
              ┌──────────────────┐
Schema        │                  │
              │   myschema.fbs   │
              │                  │
              └──────────────────┘
                        │
                        │  flatc
                        ▼
              ┌──────────────────┐                     ┌──────────────────┐
Binary schema │                  │   zig build parse   │                  │ IR
              │  myschema.bfbs   │────────────────────▶│   myschema.zon   │
              │                  │                     │                  │
              └──────────────────┘                     └──────────────────┘
                                                          ▲      │
                                                          │      │ zig build generate
                                                          │      │
                                                          └───┐  │
                                                      @import │  │
                                                              │  │
                                                              │  │
                        Runtime library                       │  ▼
                       ┌──────────────────┐            ┌──────────────────┐
                       │                  │   @import  │                  │ Encoder/decoder
                       │   flatbuffers    │◀───────────│   myschema.zig   │ library
                       │                  │            │                  │
                       └──────────────────┘            └──────────────────┘
```

First, a binary `.bfbs` schema file is decoded into a static `.zon` IR. Then, a codegen step consumes this IR and emits Zig source code containing type definitions and field accessors for the schema. The generated code uses generic functions from a runtime `flatbuffers` module to perform safe, typed, zero-copy access on serialized data.

The repo includes a special pre-generated file, `src/reflection.zig`, which is a decoder for the FlatBuffers reflection schema (`reflection.fbs`, the "schema schema"). This allows the code generator to read `.bfbs` files, creating a bootstrapping loop where the code generator both imports `reflection.zig` and can reproduce it byte-for-byte when run on `reflection.fbs`.

## Usage

We will use this example schema.

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

### Codegen

First, compile your schema to a binary `.bfbs` file using the `flatc` CLI (via [homebrew](https://formulae.brew.sh/formula/flatbuffers), [Ubuntu](https://packages.ubuntu.com/noble/flatbuffers-compiler), [Debian](https://packages.debian.org/sid/flatbuffers-compiler) etc).

```
flatc -b --schema --bfbs-comments --bfbs-builtins myschema.fbs
```

Then clone the repo and generate a `.zon` IR for the schema.

```
git clone https://github.com/nDimensional/zig-flatbuffers.git
cd zig-flatbuffers
zig build parse -- myschema.bfbs > myschema.zon
```

Then generate the Zig decoder library with

```
zig build generate -- myschema.zon | zig fmt --stdin > myschema.zig
```

Save the output to a file `myschema.zig` in the **same directory** as the `.zon` IR. You should check both files into your repo.

The generated library will something like this:

```zig
const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("myschema.zon");

pub const Fruit = enum(i8) {
    pub const @"#kind" = flatbuffers.Kind.Enum;
    pub const @"#root" = &@"#schema";
    pub const @"#type" = &@"#schema".unions[0];

    Banana = -1,
    Orange = 42,
};

pub const FooBar = struct {
    pub const @"#kind" = flatbuffers.Kind.Table;
    pub const @"#root" = &@"#schema";
    pub const @"#type" = &@"#schema".tables[0];

    @"#ref": flatbuffers.Ref,

    pub fn meal(@"#self": FooBar) Fruit {
        return flatbuffers.decodeEnumField(Fruit, 0, @"#self".@"#ref", @enumFromInt(-1));
    }

    pub fn say(@"#self": FooBar) ?flatbuffers.String {
        return flatbuffers.decodeStringField(2, @"#self".@"#ref");
    }

    pub fn height(@"#self": FooBar) i16 {
        return flatbuffers.decodeScalarField(i16, 3, @"#self".@"#ref", 0);
    }
};
```

Notice that `Fruit` is declared as a regular Zig enum type, and that the `FooBar` table is a struct with accessor methods for all of its fields. All internal declarations and fields are prefixed with `#` to prevent collisions with table field names.

### Runtime

To use the generated library, you will also have to add the `flatbuffers` module as a runtime dependency.

```
zig fetch --save=flatbuffers \
  https://github.com/nDimensional/zig-flatbuffers/archive/refs/tags/v0.1.0.tar.gz
```

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
```

#### Decoding

```zig
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

#### Building

To build a flatbuffers buffer, initialize a `flatbuffers.Builder` and then write all of your tables **bottom-up** (children first, then parents). The generic `writeTable` method takes a comptime table type and struct containing all the table fields together, and returns the same type of table reference value as the decoder methods. This reference value can be used (potentially multiple times) as a field value in a parent table.

Once you've written the root table, finalize the builder by calling `writeRoot()` method with the root table reference.

```zig
const flatbuffers = @import("flatbuffers");
const myschema = @import("myschema");

{
    // ...
    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    // ref: myschema.FooBar
    const ref = try builder.writeTable(myschema.FooBar, .{
        .meal = .Banana,
        .say = "hello",
        .height = 19,
    });

    try builder.writeRoot(myschema.FooBar, ref);

    // now you can write the finalized buffer to a writeRoot...
    try builder.write(writer);

    // ... or use an allocator to copy everything to a new buffer.
    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);
}
```

## License

MIT © 2025 nDimensional Studios
