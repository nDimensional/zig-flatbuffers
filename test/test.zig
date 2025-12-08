const std = @import("std");

const flatbuffers = @import("flatbuffers");
const reflection = @import("reflection").reflection;

const simple = @import("simple/simple.zig");

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

test "simple builder with all fields" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        const ref = try builder.writeTable(simple.FooBar, .{
            .meal = .Orange,
            .say = "comprehensive test",
            .height = 42,
        });

        try builder.writeRoot(simple.FooBar, ref);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const root = try flatbuffers.decodeRoot(simple.FooBar, result);

    try std.testing.expectEqual(42, root.height());
    try std.testing.expectEqual(simple.Fruit.Orange, root.meal());

    const say = root.say() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "comprehensive test", say);
}

test "simple builder with defaults" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Create table with minimal fields, relying on defaults
        const ref = try builder.writeTable(simple.FooBar, .{});

        try builder.writeRoot(simple.FooBar, ref);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const root = try flatbuffers.decodeRoot(simple.FooBar, result);

    // Verify defaults
    try std.testing.expectEqual(0, root.height());
    try std.testing.expectEqual(simple.Fruit.Banana, root.meal());
    try std.testing.expectEqual(@as(?flatbuffers.String, null), root.say());
}

test "simple builder with null string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        const ref = try builder.writeTable(simple.FooBar, .{
            .meal = .Banana,
            .say = null,
            .height = -100,
        });

        try builder.writeRoot(simple.FooBar, ref);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const root = try flatbuffers.decodeRoot(simple.FooBar, result);

    try std.testing.expectEqual(-100, root.height());
    try std.testing.expectEqual(simple.Fruit.Banana, root.meal());
    try std.testing.expectEqual(@as(?flatbuffers.String, null), root.say());
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

test "reflection builder with complex nested schema" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Build enum values
        const enum_val1 = try builder.writeTable(reflection.EnumVal, .{
            .name = "Red",
            .value = 0,
        });

        const enum_val2 = try builder.writeTable(reflection.EnumVal, .{
            .name = "Green",
            .value = 1,
            .documentation = &.{"A lovely green color"},
        });

        const enum_val3 = try builder.writeTable(reflection.EnumVal, .{
            .name = "Blue",
            .value = 2,
        });

        // Build the underlying type for the enum
        const enum_underlying_type = try builder.writeTable(reflection.Type, .{
            .base_type = .Byte,
            .base_size = 1,
        });

        // Build the enum itself
        const color_enum = try builder.writeTable(reflection.Enum, .{
            .name = "Color",
            .values = &.{ enum_val1, enum_val2, enum_val3 },
            .is_union = false,
            .underlying_type = enum_underlying_type,
            .documentation = &.{ "Color enumeration", "Used for various things" },
        });

        // Build a vector type
        const vector_type = try builder.writeTable(reflection.Type, .{
            .base_type = .Vector,
            .element = .UByte,
            .element_size = 1,
        });

        // Build table fields
        const field1_type = try builder.writeTable(reflection.Type, .{
            .base_type = .String,
        });

        const field1 = try builder.writeTable(reflection.Field, .{
            .name = "name",
            .type = field1_type,
            .id = 0,
            .documentation = &.{"The name field"},
        });

        const field2_type = try builder.writeTable(reflection.Type, .{
            .base_type = .Short,
            .base_size = 2,
        });

        const field2 = try builder.writeTable(reflection.Field, .{
            .name = "health",
            .type = field2_type,
            .id = 1,
            .default_integer = 100,
        });

        const field3 = try builder.writeTable(reflection.Field, .{
            .name = "inventory",
            .type = vector_type,
            .id = 2,
        });

        // Build a table object
        const monster_table = try builder.writeTable(reflection.Object, .{
            .name = "Monster",
            .fields = &.{ field1, field2, field3 },
            .is_struct = false,
            .minalign = 8,
            .bytesize = 0,
        });

        // Build the complete schema
        const schema = try builder.writeTable(reflection.Schema, .{
            .objects = &.{monster_table},
            .enums = &.{color_enum},
            .file_ident = "TEST",
            .file_ext = "bin",
            .root_table = monster_table,
        });

        try builder.writeRoot(reflection.Schema, schema);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const schema = try flatbuffers.decodeRoot(reflection.Schema, result);

    // Verify file metadata
    const file_ident = schema.file_ident() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "TEST", file_ident);

    const file_ext = schema.file_ext() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "bin", file_ext);

    // Verify objects
    const objects = schema.objects();
    try std.testing.expectEqual(1, objects.len());

    const monster = objects.get(0);
    const monster_name = monster.name();
    try std.testing.expectEqualSlices(u8, "Monster", monster_name);
    try std.testing.expectEqual(false, monster.is_struct());
    try std.testing.expectEqual(8, monster.minalign());

    // Verify fields
    const fields = monster.fields();
    try std.testing.expectEqual(3, fields.len());

    const name_field = fields.get(0);
    try std.testing.expectEqualSlices(u8, "name", name_field.name());
    try std.testing.expectEqual(0, name_field.id());

    const health_field = fields.get(1);
    try std.testing.expectEqualSlices(u8, "health", health_field.name());
    try std.testing.expectEqual(1, health_field.id());
    try std.testing.expectEqual(100, health_field.default_integer());

    const inventory_field = fields.get(2);
    try std.testing.expectEqualSlices(u8, "inventory", inventory_field.name());
    try std.testing.expectEqual(2, inventory_field.id());

    const inventory_type = inventory_field.type();
    try std.testing.expectEqual(reflection.BaseType.Vector, inventory_type.base_type());
    try std.testing.expectEqual(reflection.BaseType.UByte, inventory_type.element());

    // Verify enums
    const enums = schema.enums();
    try std.testing.expectEqual(1, enums.len());

    const color_enum = enums.get(0);
    try std.testing.expectEqualSlices(u8, "Color", color_enum.name());
    try std.testing.expectEqual(false, color_enum.is_union());

    const enum_docs = color_enum.documentation() orelse return error.Invalid;
    try std.testing.expectEqual(2, enum_docs.len());
    try std.testing.expectEqualSlices(u8, "Color enumeration", enum_docs.get(0));
    try std.testing.expectEqualSlices(u8, "Used for various things", enum_docs.get(1));

    const enum_values = color_enum.values();
    try std.testing.expectEqual(3, enum_values.len());

    const red = enum_values.get(0);
    try std.testing.expectEqualSlices(u8, "Red", red.name());
    try std.testing.expectEqual(0, red.value());

    const green = enum_values.get(1);
    try std.testing.expectEqualSlices(u8, "Green", green.name());
    try std.testing.expectEqual(1, green.value());
    const green_docs = green.documentation() orelse return error.Invalid;
    try std.testing.expectEqual(1, green_docs.len());
    try std.testing.expectEqualSlices(u8, "A lovely green color", green_docs.get(0));

    const blue = enum_values.get(2);
    try std.testing.expectEqualSlices(u8, "Blue", blue.name());
    try std.testing.expectEqual(2, blue.value());
}

test "reflection builder with services and RPCs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Build request and response tables
        const request_table = try builder.writeTable(reflection.Object, .{
            .name = "GetUserRequest",
            .is_struct = false,
            .minalign = 4,
            .bytesize = 0,
            .fields = &.{},
        });

        const response_table = try builder.writeTable(reflection.Object, .{
            .name = "GetUserResponse",
            .is_struct = false,
            .minalign = 4,
            .bytesize = 0,
            .fields = &.{},
        });

        // Build an RPC method
        const rpc = try builder.writeTable(reflection.RPCCall, .{
            .name = "GetUser",
            .request = request_table,
            .response = response_table,
            .documentation = &.{ "Retrieves a user by ID", "Returns user data or error" },
        });

        // Build a service
        const service = try builder.writeTable(reflection.Service, .{
            .name = "UserService",
            .calls = &.{rpc},
            .documentation = &.{"Main user management service"},
        });

        // Build schema with service
        const schema = try builder.writeTable(reflection.Schema, .{
            .objects = &.{ request_table, response_table },
            .enums = &.{},
            .services = &.{service},
        });

        try builder.writeRoot(reflection.Schema, schema);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const schema = try flatbuffers.decodeRoot(reflection.Schema, result);

    // Verify services
    const services = schema.services() orelse return error.Invalid;
    try std.testing.expectEqual(1, services.len());

    const service = services.get(0);
    try std.testing.expectEqualSlices(u8, "UserService", service.name());

    const service_docs = service.documentation() orelse return error.Invalid;
    try std.testing.expectEqual(1, service_docs.len());
    try std.testing.expectEqualSlices(u8, "Main user management service", service_docs.get(0));

    // Verify RPCs
    const calls = service.calls() orelse return error.Invalid;
    try std.testing.expectEqual(1, calls.len());

    const rpc = calls.get(0);
    try std.testing.expectEqualSlices(u8, "GetUser", rpc.name());

    const rpc_docs = rpc.documentation() orelse return error.Invalid;
    try std.testing.expectEqual(2, rpc_docs.len());
    try std.testing.expectEqualSlices(u8, "Retrieves a user by ID", rpc_docs.get(0));
    try std.testing.expectEqualSlices(u8, "Returns user data or error", rpc_docs.get(1));

    const request = rpc.request();
    try std.testing.expectEqualSlices(u8, "GetUserRequest", request.name());

    const response = rpc.response();
    try std.testing.expectEqualSlices(u8, "GetUserResponse", response.name());
}

test "monster builder - comprehensive test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    const Monster = @import("monster/monster.zig").MyGame.Sample.Monster;
    const Weapon = @import("monster/monster.zig").MyGame.Sample.Weapon;
    const Color = @import("monster/monster.zig").MyGame.Sample.Color;
    const Vec3 = @import("monster/monster.zig").MyGame.Sample.Vec3;

    {
        // Build weapons
        const sword = try builder.writeTable(Weapon, .{
            .name = "Sword",
            .damage = 100,
        });

        const axe = try builder.writeTable(Weapon, .{
            .name = "Axe",
            .damage = 150,
        });

        // Build monster
        const monster = try builder.writeTable(Monster, .{
            .pos = Vec3{ .x = 1.0, .y = 2.0, .z = 3.0 },
            .mana = 200,
            .hp = 300,
            .name = "Orc",
            .inventory = &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            .color = .Green,
            .weapons = &.{ sword, axe },
            .equipped_type = .{ .Weapon = sword },
            .path = &[_]Vec3{
                Vec3{ .x = 1.0, .y = 0.0, .z = 0.0 },
                Vec3{ .x = 2.0, .y = 0.0, .z = 0.0 },
                Vec3{ .x = 3.0, .y = 1.0, .z = 0.0 },
            },
        });

        try builder.writeRoot(Monster, monster);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const monster = try flatbuffers.decodeRoot(Monster, result);

    // Verify position struct
    const pos = monster.pos() orelse return error.Invalid;
    try std.testing.expectEqual(1.0, pos.x);
    try std.testing.expectEqual(2.0, pos.y);
    try std.testing.expectEqual(3.0, pos.z);

    // Verify scalar fields
    try std.testing.expectEqual(200, monster.mana());
    try std.testing.expectEqual(300, monster.hp());

    // Verify string field
    const name = monster.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "Orc", name);

    // Verify inventory vector
    const inventory = monster.inventory() orelse return error.Invalid;
    try std.testing.expectEqual(10, inventory.len());
    for (0..10) |i| {
        try std.testing.expectEqual(@as(u8, @truncate(i)), inventory.get(i));
    }

    // Verify enum field
    try std.testing.expectEqual(Color.Green, monster.color());

    // Verify weapons vector
    const weapons = monster.weapons() orelse return error.Invalid;
    try std.testing.expectEqual(2, weapons.len());

    const sword = weapons.get(0);
    const sword_name = sword.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "Sword", sword_name);
    try std.testing.expectEqual(100, sword.damage());

    const axe = weapons.get(1);
    const axe_name = axe.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "Axe", axe_name);
    try std.testing.expectEqual(150, axe.damage());

    // Verify union field
    const equipped = monster.equipped_type();
    switch (equipped) {
        .Weapon => |weapon| {
            const weapon_name = weapon.name() orelse return error.Invalid;
            try std.testing.expectEqualSlices(u8, "Sword", weapon_name);
            try std.testing.expectEqual(100, weapon.damage());
        },
        .NONE => return error.Invalid,
    }

    // Verify path vector of structs
    const path = monster.path() orelse return error.Invalid;
    try std.testing.expectEqual(3, path.len());

    const p0 = path.get(0);
    try std.testing.expectEqual(1.0, p0.x);
    try std.testing.expectEqual(0.0, p0.y);
    try std.testing.expectEqual(0.0, p0.z);

    const p1 = path.get(1);
    try std.testing.expectEqual(2.0, p1.x);
    try std.testing.expectEqual(0.0, p1.y);
    try std.testing.expectEqual(0.0, p1.z);

    const p2 = path.get(2);
    try std.testing.expectEqual(3.0, p2.x);
    try std.testing.expectEqual(1.0, p2.y);
    try std.testing.expectEqual(0.0, p2.z);
}

test "monster builder with defaults" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    const Monster = @import("monster/monster.zig").MyGame.Sample.Monster;
    const Color = @import("monster/monster.zig").MyGame.Sample.Color;
    const Vec3 = @import("monster/monster.zig").MyGame.Sample.Vec3;
    const Weapon = @import("monster/monster.zig").MyGame.Sample.Weapon;

    {
        // Build monster with minimal fields
        const monster = try builder.writeTable(Monster, .{
            .name = "Goblin",
        });

        try builder.writeRoot(Monster, monster);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const monster = try flatbuffers.decodeRoot(Monster, result);

    // Verify defaults
    try std.testing.expectEqual(@as(?Vec3, null), monster.pos());
    try std.testing.expectEqual(150, monster.mana());
    try std.testing.expectEqual(100, monster.hp());
    try std.testing.expectEqual(Color.Blue, monster.color());
    try std.testing.expectEqual(@as(?flatbuffers.Vector(u8), null), monster.inventory());
    try std.testing.expectEqual(@as(?flatbuffers.Vector(Weapon), null), monster.weapons());
    try std.testing.expectEqual(@as(?flatbuffers.Vector(Vec3), null), monster.path());

    const name = monster.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "Goblin", name);

    // Verify default union is NONE
    const equipped = monster.equipped_type();
    switch (equipped) {
        .NONE => {},
        .Weapon => return error.Invalid,
    }
}

test "monster builder with empty vectors" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    const Monster = @import("monster/monster.zig").MyGame.Sample.Monster;
    const Weapon = @import("monster/monster.zig").MyGame.Sample.Weapon;
    const Vec3 = @import("monster/monster.zig").MyGame.Sample.Vec3;

    {
        // Build monster with empty vectors
        const monster = try builder.writeTable(Monster, .{
            .name = "Skeleton",
            .inventory = &[_]u8{},
            .weapons = &[_]Weapon{},
            .path = &[_]Vec3{},
        });

        try builder.writeRoot(Monster, monster);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const monster = try flatbuffers.decodeRoot(Monster, result);

    const name = monster.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "Skeleton", name);

    // Verify empty vectors
    const inventory = monster.inventory() orelse return error.Invalid;
    try std.testing.expectEqual(0, inventory.len());

    const weapons = monster.weapons() orelse return error.Invalid;
    try std.testing.expectEqual(0, weapons.len());

    const path = monster.path() orelse return error.Invalid;
    try std.testing.expectEqual(0, path.len());
}
