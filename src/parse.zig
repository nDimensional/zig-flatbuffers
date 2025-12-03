const std = @import("std");

const flatbuffers = @import("flatbuffers");
const types = flatbuffers.types;

const lib = @import("reflection.zig");
const reflection = lib.reflection;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    data: []align(8) const u8,

    root: reflection.Schema,
    objects: flatbuffers.Vector(reflection.Object),
    enums: flatbuffers.Vector(reflection.Enum),

    field_id_map: std.ArrayList(usize) = std.ArrayList(usize).empty,

    enum_list: std.ArrayList(types.Enum) = std.ArrayList(types.Enum).empty,
    union_list: std.ArrayList(types.Union) = std.ArrayList(types.Union).empty,
    table_list: std.ArrayList(types.Table) = std.ArrayList(types.Table).empty,
    struct_list: std.ArrayList(types.Struct) = std.ArrayList(types.Struct).empty,
    bit_flags_list: std.ArrayList(types.BitFlags) = std.ArrayList(types.BitFlags).empty,

    pub fn init(allocator: std.mem.Allocator, data: []align(8) const u8) !Parser {
        const root = try flatbuffers.decodeRoot(reflection.Schema, data);
        const objects = root.objects();
        const enums = root.enums();
        return .{
            .allocator = allocator,
            .data = data,
            .root = root,
            .objects = objects,
            .enums = enums,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.field_id_map.deinit(self.allocator);

        self.enum_list.deinit(self.allocator);
        self.union_list.deinit(self.allocator);
        self.table_list.deinit(self.allocator);
        self.struct_list.deinit(self.allocator);
        self.bit_flags_list.deinit(self.allocator);
    }

    pub const ParseResult = struct {
        arena: std.heap.ArenaAllocator,
        schema: types.Schema,
    };

    pub fn parse(self: *Parser) !ParseResult {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();

        const arena_allocator = arena.allocator();

        for (0..self.enums.len()) |i| {
            const enum_ref = self.enums.get(i);
            const enum_name = enum_ref.name();
            const base_type = enum_ref.underlying_type().base_type();

            const enum_values = enum_ref.values();
            const enum_values_len = enum_values.len();
            if (enum_values_len == 0)
                return error.InvalidEnum;

            if (enum_ref.is_union()) {
                if (base_type != .UType)
                    return error.InvalidUnion;

                const options = try arena_allocator.alloc(types.Union.Option, enum_values_len - 1);

                const none_val = enum_values.get(0);
                if (none_val.value() != 0)
                    return error.InvalidUnion;
                if (none_val.union_type()) |union_type|
                    if (union_type.base_type() != .None)
                        return error.InvalidUnion;
                if (!std.mem.eql(u8, none_val.name(), "NONE"))
                    return error.InvalidUnion;

                for (options, 1..) |*option, j| {
                    const enum_val = enum_values.get(j);
                    const enum_val_name = enum_val.name();
                    const value = enum_val.value();
                    if (value != @as(i64, @intCast(j)))
                        return error.InvalidUnion;

                    const t = enum_val.union_type() orelse
                        return error.InvalidUnion;
                    if (t.base_type() != .Obj)
                        return error.InvalidUnion;

                    const object = try self.getObject(t.index());
                    if (object.is_struct())
                        return error.InvalidUnion;
                    if (!std.mem.eql(u8, enum_val_name, pop(object.name())))
                        return error.InvalidUnion;

                    option.* = .{ .table = .{ .name = try copyName(arena_allocator, object.name()) } };
                    if (enum_val.documentation()) |documentation|
                        option.documentation = try copyDocumentation(arena_allocator, documentation);
                }

                var union_t = types.Union{
                    .options = options,
                    .name = try copyName(arena_allocator, enum_name),
                };

                if (enum_ref.documentation()) |documentation|
                    union_t.documentation = try copyDocumentation(arena_allocator, documentation);

                try self.union_list.append(self.allocator, union_t);
            } else if (hasBitFlags(enum_ref)) {
                const backing_integer: types.Integer = switch (base_type) {
                    .UByte, .UShort, .UInt, .ULong => try getInteger(base_type),
                    else => return error.InvalidBitFlags,
                };

                const fields = try arena_allocator.alloc(types.BitFlags.Field, enum_values_len);

                for (fields, 0..) |*field, j| {
                    const enum_val = enum_values.get(j);
                    const enum_val_name = enum_val.name();
                    const value = enum_val.value();
                    if (value < 1 or !std.math.isPowerOfTwo(value))
                        return error.InvalidBitFlags;

                    field.* = types.BitFlags.Field{
                        .name = try copyName(arena_allocator, enum_val_name),
                        .value = @intCast(value),
                    };

                    if (enum_val.documentation()) |documentation|
                        field.documentation = try copyDocumentation(arena_allocator, documentation);
                }

                var bit_flags = types.BitFlags{
                    .name = try copyName(arena_allocator, enum_name),
                    .backing_integer = backing_integer,
                    .fields = fields,
                };

                if (enum_ref.documentation()) |documentation|
                    bit_flags.documentation = try copyDocumentation(arena_allocator, documentation);

                try self.bit_flags_list.append(self.allocator, bit_flags);
            } else {
                const backing_integer = try getInteger(base_type);

                const values = try arena_allocator.alloc(types.Enum.Value, enum_values_len);
                for (values, 0..) |*value, j| {
                    const enum_val = enum_values.get(j);
                    const enum_val_name = enum_val.name();
                    const enum_val_value = enum_val.value();
                    // TODO: check bounds on enum_val_value
                    value.* = types.Enum.Value{
                        .name = try copyName(arena_allocator, enum_val_name),
                        .value = @intCast(enum_val_value),
                    };

                    if (enum_val.documentation()) |documentation|
                        value.documentation = try copyDocumentation(arena_allocator, documentation);
                }

                var enum_t = types.Enum{
                    .name = try copyName(arena_allocator, enum_name),
                    .backing_integer = backing_integer,
                    .values = values,
                };

                if (enum_ref.documentation()) |documentation|
                    enum_t.documentation = try copyDocumentation(arena_allocator, documentation);

                try self.enum_list.append(self.allocator, enum_t);
            }
        }

        for (0..self.objects.len()) |i| {
            const object_ref = self.objects.get(i);
            const object_name = object_ref.name();

            const object_fields = object_ref.fields();
            const object_fields_len = object_fields.len();

            const field_map = try self.getFieldMap(object_fields);

            if (object_ref.is_struct()) {
                const fields = try arena_allocator.alloc(types.Struct.Field, object_fields_len);

                for (fields, 0..) |*field, j| {
                    const field_ref = object_fields.get(j);
                    const field_name = field_ref.name();
                    const field_type = field_ref.type();
                    std.log.warn(
                        "struct {s} field {s}: offset {d}, padding: {d}, type base_size: {d}",
                        .{ object_name, field_name, field_ref.offset(), field_ref.padding(), field_type.base_size() },
                    );

                    field.* = types.Struct.Field{
                        .name = try copyName(arena_allocator, field_name),
                        .type = .bool,
                        .offset = field_ref.offset(),
                    };

                    const base_type = field_type.base_type();
                    field.type = get_field: switch (base_type) {
                        .Bool => .bool,
                        .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                            const int = try getInteger(base_type);
                            break :get_field .{ .int = int };
                        },
                        .Float, .Double => {
                            const float = try getFloat(base_type);
                            break :get_field .{ .float = float };
                        },
                        .Obj => {
                            const field_object = try self.getObject(field_type.index());
                            if (!field_object.is_struct())
                                return error.InvalidStruct;

                            const field_struct_name = try copyName(arena_allocator, field_object.name());
                            break :get_field .{ .@"struct" = .{ .name = field_struct_name } };
                        },
                        .Array => {
                            const array = try arena_allocator.create(flatbuffers.types.Struct.Field.Array);
                            const element_size = field_type.element_size();
                            if (element_size > std.math.maxInt(u16))
                                return error.InvalidArray;

                            array.len = field_type.fixed_length();
                            array.element_size = @intCast(element_size);
                            array.element = get_element: switch (field_type.element()) {
                                .Bool => .bool,
                                .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                                    const int = try getInteger(base_type);
                                    break :get_element .{ .int = int };
                                },
                                .Float, .Double => {
                                    const float = try getFloat(base_type);
                                    break :get_element .{ .float = float };
                                },
                                .Obj => {
                                    const field_object = try self.getObject(field_type.index());
                                    if (!field_object.is_struct())
                                        return error.InvalidStruct;

                                    const field_struct_name = try copyName(arena_allocator, field_object.name());
                                    break :get_element .{ .@"struct" = .{ .name = field_struct_name } };
                                },
                                .Array => return error.NotImplemented,
                                else => return error.InvalidArray,
                            };

                            break :get_field .{ .array = array };
                        },
                        .UType, .Union, .String, .Vector, .Vector64, .None, .MaxBaseType => {
                            return error.InvalidStruct;
                        },
                    };

                    if (field_ref.documentation()) |documentation|
                        field.documentation = try copyDocumentation(arena_allocator, documentation);
                }

                const bytesize = object_ref.bytesize();
                if (bytesize < 0 or bytesize > std.math.maxInt(u16))
                    return error.InvalidStruct;

                const minalign = object_ref.minalign();
                if (minalign < 0 or minalign > std.math.maxInt(u16))
                    return error.InvalidStruct;

                var struct_t = types.Struct{
                    .name = try copyName(arena_allocator, object_name),
                    .fields = fields,
                    .bytesize = @intCast(bytesize),
                    .minalign = @intCast(minalign),
                };

                if (object_ref.documentation()) |documentation|
                    struct_t.documentation = try copyDocumentation(arena_allocator, documentation);

                try self.struct_list.append(self.allocator, struct_t);
            } else {
                // This requires special handling since Union types span two fields

                var union_field_count: usize = 0;

                // this is just a first pass to do validation and count the number of union fields
                for (field_map, 0..) |j, field_id| {
                    const field_ref = object_fields.get(j);
                    std.debug.assert(field_id == field_ref.id());
                    std.debug.assert(4 + 2 * field_id == field_ref.offset());

                    const field_type = field_ref.type();

                    switch (field_type.base_type()) {
                        .UType => {
                            if (field_id >= object_fields_len - 1)
                                return error.InvalidTable;
                            const next_field = object_fields.get(field_map[field_id + 1]);
                            const next_field_type = next_field.type();
                            if (next_field_type.base_type() != .Union)
                                return error.InvalidTable;

                            union_field_count += 1;
                        },
                        .Union => {
                            if (field_id == 0)
                                return error.InvalidTable;
                            const prev_field = object_fields.get(field_map[field_id - 1]);
                            const prev_field_type = prev_field.type();
                            if (prev_field_type.base_type() != .UType)
                                return error.InvalidTable;
                        },
                        else => {},
                    }
                }

                const field_count = object_fields_len - union_field_count;
                const fields = try arena_allocator.alloc(types.Table.Field, field_count);

                var field_index: usize = 0;
                for (field_map, 0..) |j, field_id| {
                    const field_ref = object_fields.get(j);
                    std.debug.assert(field_id == field_ref.id());
                    std.debug.assert(4 + 2 * field_id == field_ref.offset());

                    const field_type = field_ref.type();
                    const field_name = field_ref.name();
                    const field_base_type = field_type.base_type();
                    switch (field_base_type) {
                        .Union => continue,
                        .UType => {
                            const enum_ref = try self.getEnum(field_type.index());
                            const union_ref_name = try copyName(arena_allocator, enum_ref.name());
                            fields[field_index] = types.Table.Field{
                                .name = try copyName(arena_allocator, field_name),
                                .type = .{ .@"union" = .{ .name = union_ref_name } },
                                .deprecated = field_ref.deprecated(),
                            };
                        },
                        .Bool => {
                            fields[field_index] = types.Table.Field{
                                .name = try copyName(arena_allocator, field_name),
                                .type = .bool,
                                .deprecated = field_ref.deprecated(),
                                .default_integer = field_ref.default_integer(),
                            };
                        },
                        .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                            const enum_index = field_type.index();
                            if (enum_index == -1) {
                                fields[field_index] = types.Table.Field{
                                    .name = try copyName(arena_allocator, field_name),
                                    .type = .{ .int = try getInteger(field_base_type) },
                                    .deprecated = field_ref.deprecated(),
                                    .default_integer = field_ref.default_integer(),
                                };
                            } else {
                                const enum_ref = try self.getEnum(enum_index);

                                if (hasBitFlags(enum_ref)) {
                                    const bit_flags_ref_name = try copyName(arena_allocator, enum_ref.name());
                                    const default_integer = field_ref.default_integer();
                                    if (default_integer < 0)
                                        return error.InvalidTable;
                                    if (default_integer > 0 and !std.math.isPowerOfTwo(default_integer))
                                        return error.InvalidTable;

                                    fields[field_index] = types.Table.Field{
                                        .name = try copyName(arena_allocator, field_name),
                                        .type = .{ .bit_flags = .{ .name = bit_flags_ref_name } },
                                        .deprecated = field_ref.deprecated(),
                                        .default_integer = default_integer,
                                    };
                                } else {
                                    const enum_ref_name = try copyName(arena_allocator, enum_ref.name());
                                    fields[field_index] = types.Table.Field{
                                        .name = try copyName(arena_allocator, field_name),
                                        .type = .{ .@"enum" = .{ .name = enum_ref_name } },
                                        .deprecated = field_ref.deprecated(),
                                        .default_integer = field_ref.default_integer(),
                                    };
                                }
                            }
                        },
                        .Float, .Double => {
                            fields[field_index] = types.Table.Field{
                                .name = try copyName(arena_allocator, field_name),
                                .type = .{ .float = try getFloat(field_base_type) },
                                .deprecated = field_ref.deprecated(),
                                .default_real = field_ref.default_real(),
                            };
                        },
                        .String => {
                            fields[field_index] = types.Table.Field{
                                .name = try copyName(arena_allocator, field_name),
                                .type = .string,
                                .deprecated = field_ref.deprecated(),
                                .required = field_ref.required(),
                            };
                        },
                        .Vector => {
                            const element = field_type.element();

                            const element_type: types.Vector.Element = get_element: switch (element) {
                                .Bool => .bool,
                                .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => .{ .int = try getInteger(element) },
                                .Float, .Double => .{ .float = try getFloat(element) },
                                .String => .string,
                                .Obj => {
                                    const element_object = try self.getObject(field_type.index());
                                    const element_ref_name = try copyName(arena_allocator, element_object.name());
                                    if (element_object.is_struct()) {
                                        break :get_element .{ .@"struct" = .{ .name = element_ref_name } };
                                    } else {
                                        break :get_element .{ .table = .{ .name = element_ref_name } };
                                    }
                                },
                                .None, .UType, .Union, .Array, .Vector, .Vector64, .MaxBaseType => {
                                    return error.InvalidVectorElement;
                                },
                            };

                            const element_size = field_type.element_size();
                            if (element_size > std.math.maxInt(u16))
                                return error.InvalidVectorElement;

                            fields[field_index] = types.Table.Field{
                                .name = try copyName(arena_allocator, field_name),
                                .type = .{ .vector = .{
                                    .element = element_type,
                                    .element_size = @intCast(element_size),
                                } },
                                .deprecated = field_ref.deprecated(),
                                .required = field_ref.required(),
                            };
                        },
                        .Obj => {
                            const field_type_object = try self.getObject(field_type.index());
                            const object_ref_name = try copyName(arena_allocator, field_type_object.name());

                            if (field_type_object.is_struct()) {
                                fields[field_index] = types.Table.Field{
                                    .name = try copyName(arena_allocator, field_name),
                                    .type = .{ .@"struct" = .{ .name = object_ref_name } },
                                    .deprecated = field_ref.deprecated(),
                                    .required = field_ref.required(),
                                };
                            } else {
                                fields[field_index] = types.Table.Field{
                                    .name = try copyName(arena_allocator, field_name),
                                    .type = .{ .table = .{ .name = object_ref_name } },
                                    .deprecated = field_ref.deprecated(),
                                    .required = field_ref.required(),
                                };
                            }
                        },

                        .Vector64 => return error.NotImplemented,
                        .None, .Array, .MaxBaseType => return error.InvalidTable,
                    }

                    if (field_ref.documentation()) |documentation|
                        fields[field_index].documentation = try copyDocumentation(arena_allocator, documentation);

                    field_index += 1;
                }

                var table = types.Table{
                    .name = try copyName(arena_allocator, object_name),
                    .fields = fields,
                };

                if (object_ref.documentation()) |documentation|
                    table.documentation = try copyDocumentation(arena_allocator, documentation);

                try self.table_list.append(self.allocator, table);
            }
        }

        var schema = types.Schema{
            .bit_flags = try arena_allocator.dupe(types.BitFlags, self.bit_flags_list.items),
            .enums = try arena_allocator.dupe(types.Enum, self.enum_list.items),
            .structs = try arena_allocator.dupe(types.Struct, self.struct_list.items),
            .tables = try arena_allocator.dupe(types.Table, self.table_list.items),
            .unions = try arena_allocator.dupe(types.Union, self.union_list.items),
        };

        if (self.root.root_table()) |object|
            schema.root_table = .{ .name = try copyName(arena_allocator, object.name()) };

        return .{ .arena = arena, .schema = schema };
    }

    fn getFieldMap(self: *Parser, fields: flatbuffers.Vector(reflection.Field)) ![]const usize {
        const empty = std.math.maxInt(usize);

        try self.field_id_map.resize(self.allocator, fields.len());
        const field_map = self.field_id_map.items;

        @memset(field_map, empty);
        for (0..fields.len()) |i| {
            const id = fields.get(i).id();
            if (id >= fields.len())
                return error.InvalidFieldId;
            if (field_map[id] != empty)
                return error.DuplicateFieldId;
            field_map[id] = i;
        }

        return field_map;
    }

    inline fn getEnum(self: *Parser, enum_index: i32) !reflection.Enum {
        if (enum_index < 0 or enum_index >= self.enums.len())
            return error.InvalidEnumIndex;

        return self.enums.get(@intCast(enum_index));
    }

    inline fn getObject(self: *Parser, object_index: i32) !reflection.Object {
        if (object_index < 0 or object_index >= self.objects.len())
            return error.InvalidObjectIndex;

        return self.objects.get(@intCast(object_index));
    }
};

inline fn getInteger(base_type: reflection.BaseType) !types.Integer {
    return switch (base_type) {
        .Byte => types.Integer.i8,
        .Short => types.Integer.i16,
        .Int => types.Integer.i32,
        .Long => types.Integer.i64,
        .UByte => types.Integer.u8,
        .UShort => types.Integer.u16,
        .UInt => types.Integer.u32,
        .ULong => types.Integer.u64,
        else => return error.InvalidInteger,
    };
}

inline fn getFloat(base_type: reflection.BaseType) !types.Float {
    return switch (base_type) {
        .Float => types.Float.f32,
        .Double => types.Float.f64,
        else => return error.InvalidFloat,
    };
}

inline fn copyName(allocator: std.mem.Allocator, value: flatbuffers.String) ![]const u8 {
    return try allocator.dupe(u8, value);
}

fn copyDocumentation(allocator: std.mem.Allocator, value: flatbuffers.Vector(flatbuffers.String)) ![]const []const u8 {
    const len = value.len();
    const result = try allocator.alloc([]const u8, len);
    errdefer allocator.free(result);

    var i: usize = 0;
    errdefer for (0..i) |j| allocator.free(result[j]);
    while (i < len) : (i += 1)
        result[i] = try copyName(allocator, value.get(i));

    return result;
}

fn hasBitFlags(enum_ref: reflection.Enum) bool {
    const attributes = enum_ref.attributes() orelse return false;
    const bit_flags = findAttribute(attributes, "bit_flags");
    return bit_flags != null;
}

fn findAttribute(attributes: flatbuffers.Vector(reflection.KeyValue), key: [:0]const u8) ?reflection.KeyValue {
    for (0..attributes.len()) |i| {
        const attribute = attributes.get(i);
        const attribute_key = attribute.key();
        if (std.mem.eql(u8, key, attribute_key)) {
            return attribute;
        }
    }

    return null;
}

inline fn pop(name: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, name, '.')) |end| {
        return name[end + 1 ..];
    } else {
        return name;
    }
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var args = std.process.args();
    _ = args.next() orelse unreachable;

    const schema_path = args.next() orelse {
        std.log.err("missing schema path argument", .{});
        return;
    };

    const file = try std.fs.cwd().openFile(schema_path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try std.posix.mmap(
        null,
        stat.size,
        std.posix.PROT.READ,
        .{ .TYPE = .PRIVATE },
        file.handle,
        0,
    );

    var parser = try Parser.init(allocator, @alignCast(data));
    defer parser.deinit();

    const result = try parser.parse();
    defer result.arena.deinit();

    var buffer: [4096]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var stdout_writer = stdout.writer(&buffer);

    try result.schema.format(&stdout_writer.interface);
    try stdout_writer.interface.writeByte('\n');
    try stdout_writer.interface.flush();

    // var builder = flatbuffers.Builder.init(allocator);
    // defer builder.deinit();

    // try builder.writeTable(reflection.Object, .{
    //     .name = "wow",
    //     .fields = &.{},
    // });
}
