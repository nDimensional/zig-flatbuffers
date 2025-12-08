const std = @import("std");

const flatbuffers = @import("flatbuffers");
const reflection = @import("reflection").reflection;

const simple = @import("simple/simple.zig");
const arrow = @import("arrow/arrow.zig").org.apache.arrow.flatbuf;

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

        try builder.writeRoot(simple.FooBar, ref);
    }

    // dumpBuilderState(&builder);

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

    // dumpBuilderState(&builder);

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

test "arrow Footer with complex Schema" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Build Int type for an int32 field
        const int_type = try builder.writeTable(arrow.Int, .{
            .bitWidth = 32,
            .is_signed = true,
        });

        // Build FloatingPoint type for a float64 field
        const float_type = try builder.writeTable(arrow.FloatingPoint, .{
            .precision = .DOUBLE,
        });

        // Build Utf8 type for a string field
        const utf8_type = try builder.writeTable(arrow.Utf8, .{});

        // Build Schema fields
        const field1 = try builder.writeTable(arrow.Field, .{
            .name = "user_id",
            .nullable = false,
            .type_type = .{ .Int = int_type },
        });

        const field2 = try builder.writeTable(arrow.Field, .{
            .name = "balance",
            .nullable = true,
            .type_type = .{ .FloatingPoint = float_type },
        });

        const field3 = try builder.writeTable(arrow.Field, .{
            .name = "username",
            .nullable = true,
            .type_type = .{ .Utf8 = utf8_type },
        });

        // Build custom metadata for schema
        const metadata1 = try builder.writeTable(arrow.KeyValue, .{
            .key = "author",
            .value = "test_suite",
        });

        const metadata2 = try builder.writeTable(arrow.KeyValue, .{
            .key = "created_date",
            .value = "2025-01-01",
        });

        // Build the Schema
        const schema = try builder.writeTable(arrow.Schema, .{
            .endianness = .Little,
            .fields = &.{ field1, field2, field3 },
            .custom_metadata = &.{ metadata1, metadata2 },
            .features = &[_]i64{@intFromEnum(arrow.Feature.COMPRESSED_BODY)},
        });

        // Build Block structs for dictionaries and record batches
        const dict_block1 = arrow.Block{
            .offset = 0,
            .metaDataLength = 128,
            .bodyLength = 1024,
        };

        const dict_block2 = arrow.Block{
            .offset = 1152,
            .metaDataLength = 96,
            .bodyLength = 512,
        };

        const record_block1 = arrow.Block{
            .offset = 1760,
            .metaDataLength = 256,
            .bodyLength = 4096,
        };

        const record_block2 = arrow.Block{
            .offset = 6112,
            .metaDataLength = 192,
            .bodyLength = 8192,
        };

        const record_block3 = arrow.Block{
            .offset = 14496,
            .metaDataLength = 224,
            .bodyLength = 16384,
        };

        // Build Footer custom metadata
        const footer_metadata = try builder.writeTable(arrow.KeyValue, .{
            .key = "description",
            .value = "Sample user database export",
        });

        // Build the Footer
        const footer = try builder.writeTable(arrow.Footer, .{
            .version = .V5,
            .schema = schema,
            .dictionaries = &[_]arrow.Block{ dict_block1, dict_block2 },
            .recordBatches = &[_]arrow.Block{ record_block1, record_block2, record_block3 },
            .custom_metadata = &.{footer_metadata},
        });

        try builder.writeRoot(arrow.Footer, footer);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const footer = try flatbuffers.decodeRoot(arrow.Footer, result);

    // Verify Footer metadata
    try std.testing.expectEqual(arrow.MetadataVersion.V5, footer.version());

    // Verify schema
    const schema = footer.schema() orelse return error.Invalid;
    try std.testing.expectEqual(arrow.Endianness.Little, schema.endianness());

    // Verify schema fields
    const fields = schema.fields() orelse return error.Invalid;
    try std.testing.expectEqual(3, fields.len());

    const field1 = fields.get(0);
    const field1_name = field1.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "user_id", field1_name);
    try std.testing.expectEqual(false, field1.nullable());
    const field1_type = field1.type_type();
    switch (field1_type) {
        .Int => |int_t| {
            try std.testing.expectEqual(32, int_t.bitWidth());
            try std.testing.expectEqual(true, int_t.is_signed());
        },
        else => return error.Invalid,
    }

    const field2 = fields.get(1);
    const field2_name = field2.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "balance", field2_name);
    try std.testing.expectEqual(true, field2.nullable());
    const field2_type = field2.type_type();
    switch (field2_type) {
        .FloatingPoint => |float_t| {
            try std.testing.expectEqual(arrow.Precision.DOUBLE, float_t.precision());
        },
        else => return error.Invalid,
    }

    const field3 = fields.get(2);
    const field3_name = field3.name() orelse return error.Invalid;
    try std.testing.expectEqualSlices(u8, "username", field3_name);
    try std.testing.expectEqual(true, field3.nullable());
    const field3_type = field3.type_type();
    switch (field3_type) {
        .Utf8 => {},
        else => return error.Invalid,
    }

    // Verify schema custom metadata
    const schema_metadata = schema.custom_metadata() orelse return error.Invalid;
    try std.testing.expectEqual(2, schema_metadata.len());
    const md1 = schema_metadata.get(0);
    try std.testing.expectEqualSlices(u8, "author", md1.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "test_suite", md1.value() orelse return error.Invalid);
    const md2 = schema_metadata.get(1);
    try std.testing.expectEqualSlices(u8, "created_date", md2.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "2025-01-01", md2.value() orelse return error.Invalid);

    // Verify schema features
    const features = schema.features() orelse return error.Invalid;
    try std.testing.expectEqual(1, features.len());
    try std.testing.expectEqual(@as(i64, @intFromEnum(arrow.Feature.COMPRESSED_BODY)), features.get(0));

    // Verify dictionaries
    const dictionaries = footer.dictionaries() orelse return error.Invalid;
    try std.testing.expectEqual(2, dictionaries.len());
    const dict1 = dictionaries.get(0);
    try std.testing.expectEqual(0, dict1.offset);
    try std.testing.expectEqual(128, dict1.metaDataLength);
    try std.testing.expectEqual(1024, dict1.bodyLength);
    const dict2 = dictionaries.get(1);
    try std.testing.expectEqual(1152, dict2.offset);
    try std.testing.expectEqual(96, dict2.metaDataLength);
    try std.testing.expectEqual(512, dict2.bodyLength);

    // Verify record batches
    const record_batches = footer.recordBatches() orelse return error.Invalid;
    try std.testing.expectEqual(3, record_batches.len());
    const rec1 = record_batches.get(0);
    try std.testing.expectEqual(1760, rec1.offset);
    try std.testing.expectEqual(256, rec1.metaDataLength);
    try std.testing.expectEqual(4096, rec1.bodyLength);
    const rec2 = record_batches.get(1);
    try std.testing.expectEqual(6112, rec2.offset);
    try std.testing.expectEqual(192, rec2.metaDataLength);
    try std.testing.expectEqual(8192, rec2.bodyLength);
    const rec3 = record_batches.get(2);
    try std.testing.expectEqual(14496, rec3.offset);
    try std.testing.expectEqual(224, rec3.metaDataLength);
    try std.testing.expectEqual(16384, rec3.bodyLength);

    // Verify footer custom metadata
    const footer_metadata = footer.custom_metadata() orelse return error.Invalid;
    try std.testing.expectEqual(1, footer_metadata.len());
    const fmd = footer_metadata.get(0);
    try std.testing.expectEqualSlices(u8, "description", fmd.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "Sample user database export", fmd.value() orelse return error.Invalid);
}

test "arrow Message with RecordBatch" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Build FieldNode structs
        const field_node1 = arrow.FieldNode{
            .length = 1000,
            .null_count = 0,
        };

        const field_node2 = arrow.FieldNode{
            .length = 1000,
            .null_count = 42,
        };

        const field_node3 = arrow.FieldNode{
            .length = 1000,
            .null_count = 15,
        };

        // Build Buffer structs
        const buffer1 = arrow.Buffer{ .offset = 0, .length = 128 };
        const buffer2 = arrow.Buffer{ .offset = 128, .length = 4000 };
        const buffer3 = arrow.Buffer{ .offset = 4128, .length = 128 };
        const buffer4 = arrow.Buffer{ .offset = 4256, .length = 8000 };
        const buffer5 = arrow.Buffer{ .offset = 12256, .length = 128 };
        const buffer6 = arrow.Buffer{ .offset = 12384, .length = 12000 };

        // Build BodyCompression
        const compression = try builder.writeTable(arrow.BodyCompression, .{
            .codec = .ZSTD,
            .method = .BUFFER,
        });

        // Build RecordBatch
        const record_batch = try builder.writeTable(arrow.RecordBatch, .{
            .length = 1000,
            .nodes = &[_]arrow.FieldNode{ field_node1, field_node2, field_node3 },
            .buffers = &[_]arrow.Buffer{ buffer1, buffer2, buffer3, buffer4, buffer5, buffer6 },
            .compression = compression,
        });

        // Build custom metadata for message
        const metadata = try builder.writeTable(arrow.KeyValue, .{
            .key = "batch_id",
            .value = "batch_00042",
        });

        // Build Message with RecordBatch header
        const message = try builder.writeTable(arrow.Message, .{
            .version = .V5,
            .header_type = .{ .RecordBatch = record_batch },
            .bodyLength = 24384,
            .custom_metadata = &.{metadata},
        });

        try builder.writeRoot(arrow.Message, message);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const message = try flatbuffers.decodeRoot(arrow.Message, result);

    // Verify Message metadata
    try std.testing.expectEqual(arrow.MetadataVersion.V5, message.version());
    try std.testing.expectEqual(24384, message.bodyLength());

    // Verify custom metadata
    const metadata = message.custom_metadata() orelse return error.Invalid;
    try std.testing.expectEqual(1, metadata.len());
    const md = metadata.get(0);
    try std.testing.expectEqualSlices(u8, "batch_id", md.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "batch_00042", md.value() orelse return error.Invalid);

    // Verify header is RecordBatch
    const header = message.header_type();
    switch (header) {
        .RecordBatch => |batch| {
            try std.testing.expectEqual(1000, batch.length());

            // Verify nodes
            const nodes = batch.nodes() orelse return error.Invalid;
            try std.testing.expectEqual(3, nodes.len());
            const n1 = nodes.get(0);
            try std.testing.expectEqual(1000, n1.length);
            try std.testing.expectEqual(0, n1.null_count);
            const n2 = nodes.get(1);
            try std.testing.expectEqual(1000, n2.length);
            try std.testing.expectEqual(42, n2.null_count);
            const n3 = nodes.get(2);
            try std.testing.expectEqual(1000, n3.length);
            try std.testing.expectEqual(15, n3.null_count);

            // Verify buffers
            const buffers = batch.buffers() orelse return error.Invalid;
            try std.testing.expectEqual(6, buffers.len());
            const b1 = buffers.get(0);
            try std.testing.expectEqual(0, b1.offset);
            try std.testing.expectEqual(128, b1.length);
            const b2 = buffers.get(1);
            try std.testing.expectEqual(128, b2.offset);
            try std.testing.expectEqual(4000, b2.length);
            const b3 = buffers.get(2);
            try std.testing.expectEqual(4128, b3.offset);
            const b6 = buffers.get(5);
            try std.testing.expectEqual(12384, b6.offset);
            try std.testing.expectEqual(12000, b6.length);

            // Verify compression
            const comp = batch.compression() orelse return error.Invalid;
            try std.testing.expectEqual(arrow.CompressionType.ZSTD, comp.codec());
            try std.testing.expectEqual(arrow.BodyCompressionMethod.BUFFER, comp.method());
        },
        else => return error.Invalid,
    }
}

test "arrow Message with Tensor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Build Int type for tensor elements (int32)
        const int_type = try builder.writeTable(arrow.Int, .{
            .bitWidth = 32,
            .is_signed = true,
        });

        // Build TensorDim structs for a 3D tensor (2x3x4)
        const dim1 = try builder.writeTable(arrow.TensorDim, .{
            .size = 2,
            .name = "batch",
        });

        const dim2 = try builder.writeTable(arrow.TensorDim, .{
            .size = 3,
            .name = "height",
        });

        const dim3 = try builder.writeTable(arrow.TensorDim, .{
            .size = 4,
            .name = "width",
        });

        // Build strides (row-major: [48, 16, 4] bytes)
        const strides = &[_]i64{ 48, 16, 4 };

        // Build tensor data buffer
        const data_buffer = arrow.Buffer{
            .offset = 0,
            .length = 96, // 2 * 3 * 4 * 4 bytes
        };

        // Build Tensor
        const tensor = try builder.writeTable(arrow.Tensor, .{
            .type_type = .{ .Int = int_type },
            .shape = &.{ dim1, dim2, dim3 },
            .strides = strides,
            .data = data_buffer,
        });

        // Build custom metadata
        const metadata1 = try builder.writeTable(arrow.KeyValue, .{
            .key = "model_name",
            .value = "neural_net_weights",
        });

        const metadata2 = try builder.writeTable(arrow.KeyValue, .{
            .key = "layer",
            .value = "conv1",
        });

        // Build Message with Tensor header
        const message = try builder.writeTable(arrow.Message, .{
            .version = .V5,
            .header_type = .{ .Tensor = tensor },
            .bodyLength = 96,
            .custom_metadata = &.{ metadata1, metadata2 },
        });

        try builder.writeRoot(arrow.Message, message);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const message = try flatbuffers.decodeRoot(arrow.Message, result);

    // Verify Message metadata
    try std.testing.expectEqual(arrow.MetadataVersion.V5, message.version());
    try std.testing.expectEqual(96, message.bodyLength());

    // Verify custom metadata
    const metadata = message.custom_metadata() orelse return error.Invalid;
    try std.testing.expectEqual(2, metadata.len());
    const md1 = metadata.get(0);
    try std.testing.expectEqualSlices(u8, "model_name", md1.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "neural_net_weights", md1.value() orelse return error.Invalid);
    const md2 = metadata.get(1);
    try std.testing.expectEqualSlices(u8, "layer", md2.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "conv1", md2.value() orelse return error.Invalid);

    // Verify header is Tensor
    const header = message.header_type();
    switch (header) {
        .Tensor => |tensor| {
            // Verify tensor type
            const tensor_type = tensor.type_type();
            switch (tensor_type) {
                .Int => |int_t| {
                    try std.testing.expectEqual(32, int_t.bitWidth());
                    try std.testing.expectEqual(true, int_t.is_signed());
                },
                else => return error.Invalid,
            }

            // Verify shape
            const shape = tensor.shape();
            try std.testing.expectEqual(3, shape.len());
            const d1 = shape.get(0);
            try std.testing.expectEqual(2, d1.size());
            try std.testing.expectEqualSlices(u8, "batch", d1.name() orelse return error.Invalid);
            const d2 = shape.get(1);
            try std.testing.expectEqual(3, d2.size());
            try std.testing.expectEqualSlices(u8, "height", d2.name() orelse return error.Invalid);
            const d3 = shape.get(2);
            try std.testing.expectEqual(4, d3.size());
            try std.testing.expectEqualSlices(u8, "width", d3.name() orelse return error.Invalid);

            // Verify strides
            const strides = tensor.strides() orelse return error.Invalid;
            try std.testing.expectEqual(3, strides.len());
            try std.testing.expectEqual(48, strides.get(0));
            try std.testing.expectEqual(16, strides.get(1));
            try std.testing.expectEqual(4, strides.get(2));

            // Verify data buffer
            const data = tensor.data();
            try std.testing.expectEqual(0, data.offset);
            try std.testing.expectEqual(96, data.length);
        },
        else => return error.Invalid,
    }
}

test "arrow Message with SparseTensor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var builder = try flatbuffers.Builder.init(allocator);
    defer builder.deinit();

    {
        // Build FloatingPoint type for sparse tensor elements (float64)
        const float_type = try builder.writeTable(arrow.FloatingPoint, .{
            .precision = .DOUBLE,
        });

        // Build TensorDim structs for a 3D sparse tensor (100x200x150)
        const dim1 = try builder.writeTable(arrow.TensorDim, .{
            .size = 100,
            .name = "x",
        });

        const dim2 = try builder.writeTable(arrow.TensorDim, .{
            .size = 200,
            .name = "y",
        });

        const dim3 = try builder.writeTable(arrow.TensorDim, .{
            .size = 150,
            .name = "z",
        });

        // Build Int type for COO indices (int64)
        const indices_int_type = try builder.writeTable(arrow.Int, .{
            .bitWidth = 64,
            .is_signed = true,
        });

        // Build COO index buffers
        const indices_buffer = arrow.Buffer{
            .offset = 0,
            .length = 384, // 16 non-zero values * 3 dimensions * 8 bytes
        };

        // Build SparseTensorIndexCOO
        const coo_index = try builder.writeTable(arrow.SparseTensorIndexCOO, .{
            .indicesType = indices_int_type,
            .indicesBuffer = indices_buffer,
            .isCanonical = true,
        });

        // Build sparse tensor data buffer (16 non-zero float64 values)
        const data_buffer = arrow.Buffer{
            .offset = 384,
            .length = 128, // 16 * 8 bytes
        };

        // Build SparseTensor
        const sparse_tensor = try builder.writeTable(arrow.SparseTensor, .{
            .type_type = .{ .FloatingPoint = float_type },
            .shape = &.{ dim1, dim2, dim3 },
            .non_zero_length = 16,
            .sparseIndex_type = .{ .SparseTensorIndexCOO = coo_index },
            .data = data_buffer,
        });

        // Build custom metadata
        const metadata1 = try builder.writeTable(arrow.KeyValue, .{
            .key = "matrix_type",
            .value = "adjacency_sparse",
        });

        const metadata2 = try builder.writeTable(arrow.KeyValue, .{
            .key = "sparsity",
            .value = "0.9995", // 16 / (100 * 200 * 150) ≈ 0.00053
        });

        // Build Message with SparseTensor header
        const message = try builder.writeTable(arrow.Message, .{
            .version = .V5,
            .header_type = .{ .SparseTensor = sparse_tensor },
            .bodyLength = 512,
            .custom_metadata = &.{ metadata1, metadata2 },
        });

        try builder.writeRoot(arrow.Message, message);
    }

    const result = try builder.writeAlloc(allocator);
    defer allocator.free(result);

    const message = try flatbuffers.decodeRoot(arrow.Message, result);

    // Verify Message metadata
    try std.testing.expectEqual(arrow.MetadataVersion.V5, message.version());
    try std.testing.expectEqual(512, message.bodyLength());

    // Verify custom metadata
    const metadata = message.custom_metadata() orelse return error.Invalid;
    try std.testing.expectEqual(2, metadata.len());
    const md1 = metadata.get(0);
    try std.testing.expectEqualSlices(u8, "matrix_type", md1.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "adjacency_sparse", md1.value() orelse return error.Invalid);
    const md2 = metadata.get(1);
    try std.testing.expectEqualSlices(u8, "sparsity", md2.key() orelse return error.Invalid);
    try std.testing.expectEqualSlices(u8, "0.9995", md2.value() orelse return error.Invalid);

    // Verify header is SparseTensor
    const header = message.header_type();
    switch (header) {
        .SparseTensor => |sparse_tensor| {
            // Verify sparse tensor type
            const tensor_type = sparse_tensor.type_type();
            switch (tensor_type) {
                .FloatingPoint => |float_t| {
                    try std.testing.expectEqual(arrow.Precision.DOUBLE, float_t.precision());
                },
                else => return error.Invalid,
            }

            // Verify shape
            const shape = sparse_tensor.shape();
            try std.testing.expectEqual(3, shape.len());
            const d1 = shape.get(0);
            try std.testing.expectEqual(100, d1.size());
            try std.testing.expectEqualSlices(u8, "x", d1.name() orelse return error.Invalid);
            const d2 = shape.get(1);
            try std.testing.expectEqual(200, d2.size());
            try std.testing.expectEqualSlices(u8, "y", d2.name() orelse return error.Invalid);
            const d3 = shape.get(2);
            try std.testing.expectEqual(150, d3.size());
            try std.testing.expectEqualSlices(u8, "z", d3.name() orelse return error.Invalid);

            // Verify non-zero length
            try std.testing.expectEqual(16, sparse_tensor.non_zero_length());

            // Verify sparse index is COO
            const sparse_index = sparse_tensor.sparseIndex_type();
            switch (sparse_index) {
                .SparseTensorIndexCOO => |coo| {
                    // Verify indices type
                    const indices_type = coo.indicesType();
                    try std.testing.expectEqual(64, indices_type.bitWidth());
                    try std.testing.expectEqual(true, indices_type.is_signed());

                    // Verify indices buffer
                    const indices_buffer = coo.indicesBuffer();
                    try std.testing.expectEqual(0, indices_buffer.offset);
                    try std.testing.expectEqual(384, indices_buffer.length);

                    // Verify canonical flag
                    try std.testing.expectEqual(true, coo.isCanonical());
                },
                else => return error.Invalid,
            }

            // Verify data buffer
            const data = sparse_tensor.data();
            try std.testing.expectEqual(384, data.offset);
            try std.testing.expectEqual(128, data.length);
        },
        else => return error.Invalid,
    }
}
