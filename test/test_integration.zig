const std = @import("std");
const flatbuffers = @import("flatbuffers");

// Import our Zig-generated schemas
const simple = @import("simple/simple.zig").Eclectic;
const monster = @import("monster/monster.zig").MyGame.Sample;

// C FFI imports for flatcc helpers (avoids alignment issues with Zig's C translation)
const simple_c = @cImport({
    @cInclude("simple/flatcc_helpers.h");
});

const monster_c = @cImport({
    @cInclude("monster/flatcc_helpers.h");
});

test "simple - flatcc round trip through helpers" {
    // Test building with C and reading with C
    var buffer: ?*anyopaque = null;
    var size: usize = 0;

    const result = simple_c.eclectic_foobar_build(&buffer, &size, 42, "test", 100);
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer simple_c.eclectic_foobar_free_buffer(buffer);

    const root = simple_c.eclectic_foobar_read(buffer);
    try std.testing.expect(root != null);

    const meal = simple_c.eclectic_foobar_meal(root);
    try std.testing.expectEqual(@as(i8, 42), meal);

    const height = simple_c.eclectic_foobar_height(root);
    try std.testing.expectEqual(@as(i16, 100), height);

    const say = simple_c.eclectic_foobar_say(root);
    try std.testing.expect(say != null);
    const say_slice = std.mem.span(say);
    try std.testing.expectEqualSlices(u8, "test", say_slice);
}

test "simple schema - Zig encode -> flatcc decode" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // Build using Zig
    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    const ref = try builder.writeTable(simple.FooBar, .{
        .meal = .Orange,
        .say = "hello from zig",
        .height = 42,
    });

    try builder.writeRoot(simple.FooBar, ref);

    const buffer = try builder.writeAlloc(allocator);
    defer allocator.free(buffer);

    // Verify using Zig decoder first (sanity check)
    const zig_root = try flatbuffers.decodeRoot(simple.FooBar, buffer);
    try std.testing.expectEqual(simple.Fruit.Orange, zig_root.meal());
    try std.testing.expectEqual(@as(i16, 42), zig_root.height());

    // Now verify using flatcc reader via our C helpers
    const root = simple_c.eclectic_foobar_read(buffer.ptr);
    try std.testing.expect(root != null);

    const meal = simple_c.eclectic_foobar_meal(root);
    try std.testing.expectEqual(@as(i8, 42), meal);

    const height = simple_c.eclectic_foobar_height(root);
    try std.testing.expectEqual(@as(i16, 42), height);

    const say = simple_c.eclectic_foobar_say(root);
    try std.testing.expect(say != null);
    const say_slice = std.mem.span(say);
    try std.testing.expectEqualSlices(u8, "hello from zig", say_slice);
}

test "simple - flatcc encode -> Zig decode" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // Build using flatcc
    var buffer: ?*anyopaque = null;
    var size: usize = 0;

    const result = simple_c.eclectic_foobar_build(&buffer, &size, -1, "hello from flatcc", 99);
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer simple_c.eclectic_foobar_free_buffer(buffer);

    // Copy to Zig-aligned buffer
    const zig_buffer = try allocator.alignedAlloc(u8, .@"8", size);
    defer allocator.free(zig_buffer);
    @memcpy(zig_buffer, @as([*]const u8, @ptrCast(buffer))[0..size]);

    // Verify using Zig decoder
    const zig_root = try flatbuffers.decodeRoot(simple.FooBar, zig_buffer);
    try std.testing.expectEqual(simple.Fruit.Banana, zig_root.meal());
    try std.testing.expectEqual(@as(i16, 99), zig_root.height());

    const say = zig_root.say() orelse return error.MissingField;
    try std.testing.expectEqualSlices(u8, "hello from flatcc", say);
}

test "monster - flatcc round trip" {
    // Test building with C and reading with C
    var buffer: ?*anyopaque = null;
    var size: usize = 0;

    const pos = monster_c.Vec3{ .x = 1.0, .y = 2.0, .z = 3.0 };
    const result = monster_c.monster_build_simple(&buffer, &size, "Orc", 300, 150, 2, pos);
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer monster_c.monster_free_buffer(buffer);

    const root = monster_c.monster_read(buffer);
    try std.testing.expect(root != null);

    const name = monster_c.monster_name(root);
    try std.testing.expect(name != null);
    const name_slice = std.mem.span(name);
    try std.testing.expectEqualSlices(u8, "Orc", name_slice);

    const hp = monster_c.monster_hp(root);
    try std.testing.expectEqual(@as(i16, 300), hp);

    const mana = monster_c.monster_mana(root);
    try std.testing.expectEqual(@as(i16, 150), mana);

    const color = monster_c.monster_color(root);
    try std.testing.expectEqual(@as(i8, 2), color); // Blue

    const read_pos = monster_c.monster_pos(root);
    try std.testing.expectEqual(@as(f32, 1.0), read_pos.x);
    try std.testing.expectEqual(@as(f32, 2.0), read_pos.y);
    try std.testing.expectEqual(@as(f32, 3.0), read_pos.z);
}

test "monster - Zig encode -> flatcc decode" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // Build using Zig
    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    const ref = try builder.writeTable(monster.Monster, .{
        .pos = .{ .x = 10.0, .y = 20.0, .z = 30.0 },
        .name = "Dragon",
        .hp = 500,
        .mana = 200,
        .color = .Red,
    });

    try builder.writeRoot(monster.Monster, ref);

    const buffer = try builder.writeAlloc(allocator);
    defer allocator.free(buffer);

    // Verify using Zig decoder first
    const zig_root = try flatbuffers.decodeRoot(monster.Monster, buffer);
    try std.testing.expectEqual(@as(i16, 500), zig_root.hp());

    // Now verify using flatcc reader
    const root = monster_c.monster_read(buffer.ptr);
    try std.testing.expect(root != null);

    const name = monster_c.monster_name(root);
    try std.testing.expect(name != null);
    const name_slice = std.mem.span(name);
    try std.testing.expectEqualSlices(u8, "Dragon", name_slice);

    const hp = monster_c.monster_hp(root);
    try std.testing.expectEqual(@as(i16, 500), hp);

    const mana = monster_c.monster_mana(root);
    try std.testing.expectEqual(@as(i16, 200), mana);

    const color = monster_c.monster_color(root);
    try std.testing.expectEqual(@as(i8, 0), color); // Red

    const pos = monster_c.monster_pos(root);
    try std.testing.expectEqual(@as(f32, 10.0), pos.x);
    try std.testing.expectEqual(@as(f32, 20.0), pos.y);
    try std.testing.expectEqual(@as(f32, 30.0), pos.z);
}

test "monster - flatcc encode -> Zig decode" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // Build using flatcc
    var buffer: ?*anyopaque = null;
    var size: usize = 0;

    const pos = monster_c.Vec3{ .x = 5.0, .y = 6.0, .z = 7.0 };
    const result = monster_c.monster_build_simple(&buffer, &size, "Goblin", 50, 100, 1, pos);
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer monster_c.monster_free_buffer(buffer);

    // Copy to Zig-aligned buffer
    const zig_buffer = try allocator.alignedAlloc(u8, .@"8", size);
    defer allocator.free(zig_buffer);
    @memcpy(zig_buffer, @as([*]const u8, @ptrCast(buffer))[0..size]);

    // Verify using Zig decoder
    const zig_root = try flatbuffers.decodeRoot(monster.Monster, zig_buffer);

    const name = zig_root.name() orelse return error.MissingField;
    try std.testing.expectEqualSlices(u8, "Goblin", name);

    try std.testing.expectEqual(@as(i16, 50), zig_root.hp());
    try std.testing.expectEqual(@as(i16, 100), zig_root.mana());
    try std.testing.expectEqual(monster.Color.Green, zig_root.color());

    const zig_pos = zig_root.pos() orelse return error.MissingField;
    try std.testing.expectEqual(@as(f32, 5.0), zig_pos.x);
    try std.testing.expectEqual(@as(f32, 6.0), zig_pos.y);
    try std.testing.expectEqual(@as(f32, 7.0), zig_pos.z);
}
