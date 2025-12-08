const std = @import("std");

const flatbuffers = @import("flatbuffers");
const reflection = @import("reflection").reflection;

const simple = @import("simple/simple.zig");

// test "simple builder" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer std.debug.assert(gpa.deinit() == .ok);
//     const allocator = gpa.allocator();

//     var builder = try flatbuffers.Builder.init(allocator);
//     defer builder.deinit();

//     _ = try builder.writeString("hello world");

//     std.log.warn("builder blocks: ({d}) offset {d}", .{ builder.blocks.items.len, builder.offset });
//     for (0..builder.blocks.items.len) |i| {
//         const j = builder.blocks.items.len - i - 1;
//         const block = builder.blocks.items[j];
//         std.log.warn("- {d} {*} (len {d})", .{ j, block.ptr, block.len });
//         std.log.warn("    {x}", .{block});
//     }
// }

fn dumpBuilderState(builder: *const flatbuffers.Builder) void {
    std.log.warn("builder blocks: ({d}) offset {d}", .{ builder.blocks.items.len, builder.offset });
    for (0..builder.blocks.items.len) |i| {
        const block = builder.blocks.items[i];
        std.log.warn("- {d} {*}", .{ i, block.ptr });
        std.log.warn("  {x}", .{block});
    }
}

test "simple builder" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        const ref = try builder.writeTable(simple.FooBar, .{
            .meal = .Banana,
            .say = "hello",
            .height = 19,
        });

        std.log.warn("ref: {any}", .{ref});
        std.log.warn("ref: {x}", .{ref.@"#ref".ptr[ref.@"#ref".offset..ref.@"#ref".len]});

        try builder.writeRoot(simple.FooBar, ref);
    }

    dumpBuilderState(&builder);

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const root = try flatbuffers.decodeRoot(simple.FooBar, result);

    try std.testing.expectEqual(19, root.height());
    try std.testing.expectEqual(simple.Fruit.Banana, root.meal());

    const say = root.say() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "hello", say);
}

test "reflection builder" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        const type_ref = try builder.writeTable(reflection.Type, .{
            // base_type: reflection.BaseType = @enumFromInt(0),
            // element: reflection.BaseType = @enumFromInt(0),
            // index: i32 = -1,
            // fixed_length: u16 = 0,
            // base_size: u32 = 4,
            // element_size: u32 = 0,
        });

        const field_ref = try builder.writeTable(reflection.Field, .{
            .name = "MyFieldName",
            .type = type_ref,
            .id = 8,
            .documentation = &.{ "0", "1", "2", "3" },
        });

        try builder.writeRoot(reflection.Field, field_ref);
    }

    dumpBuilderState(&builder);

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const field_ref = try flatbuffers.decodeRoot(reflection.Field, result);

    try std.testing.expectEqual(8, field_ref.id());

    const documentation = field_ref.documentation() orelse return error.Invalid;
    for (0..documentation.len()) |i|
        try std.testing.expectEqualSlices(u8, &.{'0' + @as(u8, @truncate(i))}, documentation.get(i));

    const type_ref = field_ref.type();
    try std.testing.expectEqual(0, type_ref.element_size());
    try std.testing.expectEqual(-1, type_ref.index());
}
