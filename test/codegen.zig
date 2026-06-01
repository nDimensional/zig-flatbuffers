const std = @import("std");

// `simple` is generated at build time from `test/simple/simple.fbs` by the
// managed `addSchemaModule` pipeline (flatc -> zfbs-parse -> zfbs-generate),
// without any checked-in artifacts or a locally installed flatc.
const simple = @import("simple");

test "managed codegen produces an importable, usable decoder" {
    // Referencing the generated declarations ensures the whole build-time
    // pipeline produced a module that actually type-checks.
    try std.testing.expectEqual(flatbuffersKind(simple.Eclectic.FooBar), .Table);
    try std.testing.expectEqual(flatbuffersKind(simple.Eclectic.Fruit), .Enum);

    // The generated enum mirrors the schema's values.
    try std.testing.expectEqual(@as(i8, -1), @intFromEnum(simple.Eclectic.Fruit.Banana));
    try std.testing.expectEqual(@as(i8, 42), @intFromEnum(simple.Eclectic.Fruit.Orange));
}

fn flatbuffersKind(comptime T: type) @TypeOf(T.@"#kind") {
    return T.@"#kind";
}
