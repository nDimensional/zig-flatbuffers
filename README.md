# zig-flatbuffers

**Very WIP.**

First, compile your Flatbuffers schema to a binary .bfbs file

```
flatc -b --schema --bfbs-comments --bfbs-builtins myschema.fbs
```

Then generate the Zig decoder library with

```
zig build && ./zig-out/bin/codegen myschema.bfbs | zig fmt --stdin
```
