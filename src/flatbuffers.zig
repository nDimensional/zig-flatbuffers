const std = @import("std");

pub const types = @import("types.zig");

pub const Ref = struct {
    ptr: [*]align(8) const u8,
    len: u32,
    offset: u32,

    pub inline fn uoffset(ref: Ref) Ref {
        return ref.add(ref.decodeScalar(u32));
    }

    pub inline fn soffset(ref: Ref) Ref {
        return ref.sub(ref.decodeScalar(i32));
    }

    pub inline fn add(ref: Ref, offset: u32) Ref {
        var result: u64 = @intCast(ref.offset);
        result += offset;
        if (result > ref.len)
            @panic("unsigned offset overflow");
        return .{ .ptr = ref.ptr, .len = ref.len, .offset = @intCast(result) };
    }

    pub inline fn sub(ref: Ref, offset: i32) Ref {
        var result: i64 = @intCast(ref.offset);
        result -= offset;
        if (result < 0)
            @panic("signed offset underflow");
        if (result > ref.len)
            @panic("signed offset overflow");

        return .{ .ptr = ref.ptr, .len = ref.len, .offset = @intCast(result) };
    }

    pub inline fn decodeScalar(ref: Ref, comptime T: type) T {
        const data = ref.ptr[ref.offset..ref.len][0..@sizeOf(T)];
        return switch (@typeInfo(T)) {
            .int => |info| switch (info.bits) {
                8, 16, 32, 64 => std.mem.readInt(T, data, .little),
                else => @compileError("only 8, 16, 32, and 64-bit integers are supported"),
            },
            .float => |info| switch (info.bits) {
                32 => @bitCast(std.mem.readInt(u32, data, .little)),
                64 => @bitCast(std.mem.readInt(u64, data, .little)),
                else => @compileError("only 32 and 64bit floats are supported"),
            },
            .bool => data[0] != 0,
            else => @compileError("expected scalar value"),
        };
    }

    pub inline fn decodeEnum(ref: Ref, comptime T: type) T {
        const info = switch (@typeInfo(T)) {
            .@"enum" => |info| info,
            else => @compileError("invalid enum type"),
        };

        return @enumFromInt(ref.decodeScalar(info.tag_type));
    }
};

/// Used to differentiate the kinds of struct declarations
pub const Kind = enum {
    Table,
    Struct,
    BitFlags,
    Vector,
    Union,
    Enum,
};

pub const String = [:0]const u8;

pub fn Vector(comptime T: type) type {
    return struct {
        pub const @"#kind" = Kind.Vector;
        pub const @"#type" = getVectorType(T);
        const item_size = getVectorElementSize(T);

        const Self = @This();

        @"#ref": Ref,

        pub inline fn len(self: Self) usize {
            return self.@"#ref".decodeScalar(u32);
        }

        pub fn at(self: Self, index: usize) T {
            const i: u32 = @truncate(index);
            const item_ref = self.@"#ref".add(@sizeOf(u32) + item_size * i);
            return switch (@typeInfo(T)) {
                .int, .float, .bool => item_ref.decodeScalar(T),
                .pointer => decodeString(item_ref),
                .@"enum" => item_ref.decodeEnum(T),
                .@"struct" => switch (@field(T, "#kind")) {
                    Kind.Table => decodeTable(T, item_ref),
                    Kind.Struct => @compileError("not implemented"),
                    Kind.BitFlags => decodeBitFlags(T, item_ref),
                    Kind.Vector => @compileError("cannot nest vectors"),
                    Kind.Union, Kind.Enum => @compileError("invalid struct declaration"),
                },
                else => @compileError("invalid vector type"),
            };
        }
    };
}

fn getVectorType(comptime T: type) types.Vector {
    const element = switch (@typeInfo(T)) {
        .bool => types.Vector.Element.bool,
        .int => |info| types.Vector.Element{
            .int = switch (info.bits) {
                8 => if (info.signed) .i8 else .u8,
                16 => if (info.signed) .i16 else .u16,
                32 => if (info.signed) .i32 else .u32,
                64 => if (info.signed) .i64 else .u64,
                else => @compileError("invalid integer type"),
            },
        },
        .float => |info| types.Vector.Element{
            .float = switch (info.bits) {
                32 => .f32,
                64 => .f64,
            },
        },
        .pointer => types.Vector.Element.string,
        .@"enum" => types.Vector.Element{
            .@"enum" = .{ .name = @as(types.Enum, @field(T, "#type")).name },
        },
        .@"struct" => switch (@field(T, "#kind")) {
            Kind.Table => types.Vector.Element{
                .table = .{ .name = @as(types.Table, @field(T, "#type")).name },
            },
            Kind.Vector => @compileError("cannot nest vectors"),
            Kind.Struct => types.Vector.Element{
                .@"struct" = .{ .name = @as(types.Struct, @field(T, "#type")).name },
            },
            Kind.BitFlags => types.Vector.Element{
                .bit_flags = .{ .name = @as(types.BitFlags, @field(T, "#type")).name },
            },
            Kind.Union, Kind.Enum => @compileError("invalid struct declaration"),
        },
        else => @compileError("invalid vector type"),
    };

    return types.Vector{ .element = element };
}

fn getVectorElementSize(comptime T: type) u32 {
    return switch (@typeInfo(T)) {
        .int, .float, .bool => @sizeOf(T),
        .pointer => @sizeOf(u32),
        .@"enum" => |info| @sizeOf(info.tag_type),
        .@"struct" => switch (@field(T, "#kind")) {
            Kind.Table => @sizeOf(u32),
            Kind.Vector => @compileError("cannot nest vectors"),
            Kind.Struct => getStructSize(T),
            Kind.BitFlags => {
                const bit_flags: types.BitFlags = @field(T, "#type");
                return switch (bit_flags.backing_integer) {
                    .u8 => 1,
                    .u16 => 2,
                    .u32 => 4,
                    .u64 => 8,
                    else => @compileError("invalid bit flags backing integer"),
                };
            },
            Kind.Union, Kind.Enum => @compileError("invalid struct declaration"),
        },

        else => @compileError("unexpected type"),
    };
}

fn getStructSize(comptime T: type) u32 {
    switch (@typeInfo(T)) {
        .int, .float, .bool => return @sizeOf(T),
        .array => |info| return info.len * getStructSize(info.child),
        .@"struct" => |info| {
            var size: u32 = 0;
            inline for (info.fields) |field| {
                const field_alignment = getStructAlignment(field.type);
                size = std.mem.alignForward(u32, size, field_alignment);
                size += getStructSize(field.type);
            }

            return std.mem.alignForward(u32, size, getStructAlignment(T));
        },
        else => @compileError("invalid struct field type"),
    }
}

fn getStructAlignment(comptime T: type) u32 {
    switch (@typeInfo(T)) {
        .int, .float, .bool => return @sizeOf(T),
        .@"enum" => |info| return @sizeOf(info.tag_type),
        .array => |info| return getStructAlignment(info.child),
        .@"struct" => |info| {
            var max_alignment: u32 = 0;
            inline for (info.fields) |field|
                max_alignment = @max(max_alignment, getStructAlignment(field.type));

            return max_alignment;
        },
        else => @compileError("invalid struct field type"),
    }
}

pub inline fn decodeScalarField(comptime T: type, comptime id: u16, table_ref: Ref, comptime default: T) T {
    const field_ref = getFieldRef(table_ref, id) orelse
        return default;
    return field_ref.decodeScalar(T);
}

pub inline fn decodeEnumField(comptime T: type, comptime id: u16, table_ref: Ref, comptime default: T) T {
    const field_ref = getFieldRef(table_ref, id) orelse
        return default;
    return field_ref.decodeEnum(T);
}

pub inline fn decodeBitFlagsField(comptime T: type, comptime id: u16, table_ref: Ref, comptime default: T) T {
    const field_ref = getFieldRef(table_ref, id) orelse
        return default;
    return decodeBitFlags(T, field_ref);
}

pub fn decodeStructField(comptime T: type, comptime id: u16, table_ref: Ref) ?T {
    const field_ref = getFieldRef(table_ref, id) orelse
        return null;

    return decodeStruct(T, field_ref);
}

pub inline fn decodeTableField(comptime T: type, comptime id: u16, table_ref: Ref) ?T {
    const field_ref = getFieldRef(table_ref, id) orelse
        return null;
    return decodeTable(T, field_ref);
}

pub inline fn decodeUnionField(comptime T: type, comptime tag_id: u16, comptime ref_id: u16, table_ref: Ref) T {
    const tag_type: type = switch (@typeInfo(T)) {
        .@"union" => |info| info.tag_type orelse
            @compileError("expected tagged union type"),
        else => @compileError("expected tagged union type"),
    };

    const tag_fields = switch (@typeInfo(tag_type)) {
        .@"enum" => |info| info.fields,
        else => @compileError("expected enum tag type"),
    };

    const tag_field_ref = getFieldRef(table_ref, tag_id) orelse
        return @unionInit(T, "NONE", {});

    const data = tag_field_ref.ptr[tag_field_ref.offset..tag_field_ref.len][0..@sizeOf(tag_type)];
    const tag_value = std.mem.readInt(tag_type, data, .little);

    if (tag_value == 0)
        return @unionInit(T, "NONE", {});

    const ref_field_ref = getFieldRef(table_ref, ref_id) orelse
        return @unionInit(T, "NONE", {});

    const ref_ref = ref_field_ref.uoffset();

    inline for (tag_fields) |tag_field| {
        if (tag_field.value == tag_value) {
            return @unionInit(T, tag_field.name, .{ .offset = ref_ref });
        }
    }
}

pub inline fn decodeVectorField(comptime T: type, comptime id: u16, table_ref: Ref) ?Vector(T) {
    const field_ref = getFieldRef(table_ref, id) orelse
        return null;
    return decodeVector(T, field_ref);
}

pub inline fn decodeStringField(comptime id: u16, table_ref: Ref) ?String {
    const field_ref = getFieldRef(table_ref, id) orelse
        return null;
    return decodeString(field_ref);
}

inline fn decodeBitFlags(comptime T: type, ref: Ref) T {
    if (@field(T, "#kind") != Kind.BitFlags)
        @compileError("expected bit flags type");

    const info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError("expected bit flags type"),
    };

    const bit_flags: types.BitFlags = comptime @field(T, "#type");

    if (bit_flags.fields.len != info.fields.len)
        @compileError("invalid bit flag fields");

    const value: u64 = @intCast(switch (bit_flags.backing_integer) {
        .u8 => std.mem.readInt(u8, ref.ptr[0..ref.len][0..@sizeOf(u8)], .little),
        .u16 => std.mem.readInt(u16, ref.ptr[0..ref.len][0..@sizeOf(u16)], .little),
        .u32 => std.mem.readInt(u32, ref.ptr[0..ref.len][0..@sizeOf(u32)], .little),
        .u64 => std.mem.readInt(u64, ref.ptr[0..ref.len][0..@sizeOf(u64)], .little),
        else => @compileError("invalid bit flags backing integer"),
    });

    var result: T = .{};
    inline for (info.fields, bit_flags.fields) |field, flag| {
        if (field.type != bool)
            @compileError("invalid bit flag fields");

        @field(result, field.name) = value & flag.value != 0;
    }

    return result;
}

inline fn decodeTable(comptime T: type, ref: Ref) T {
    if (@field(T, "#kind") != Kind.Table)
        @compileError("expected table type");

    return T{ .@"#ref" = ref.uoffset() };
}

inline fn decodeVector(comptime T: type, ref: Ref) Vector(T) {
    return Vector(T){ .@"#ref" = ref.uoffset() };
}

fn decodeString(ref: Ref) String {
    const str_ref = ref.uoffset();
    const str_len = str_ref.decodeScalar(u32);
    const offset = str_ref.offset + @sizeOf(u32);
    return str_ref.ptr[offset .. offset + str_len :0];
}

fn decodeStruct(comptime T: type, ref: Ref) T {
    if (@field(T, "#kind") != Kind.Struct)
        @compileError("expected struct type");

    const struct_t: types.Struct = comptime @field(T, "#type");

    var result: T = undefined;
    inline for (struct_t.fields) |field| {
        const FieldType = @FieldType(T, field.name);

        @field(result, field.name) = undefined;
        const field_ref = ref.add(field.offset);
        @field(result, field.name) = get_field: switch (field.type) {
            .bool, .int, .float => field_ref.decodeScalar(FieldType),
            .array => |array| {
                const array_info = switch (@typeInfo(FieldType)) {
                    .array => |info| info,
                    else => @compileError("expected array type"),
                };

                if (array_info.len != array.len)
                    @compileError("expected equal array lengths");

                var array_result: FieldType = undefined;
                for (&array_result, 0..) |*element, i| {
                    const element_ref = field_ref.add(@intCast(i * array.element_size));
                    element.* = switch (field.type) {
                        .bool, .int, .float => element_ref.decodeScalar(array.element),
                        .array => @compileError("not implemented (nested arrays)"),
                        .@"struct" => decodeStruct(array.element, element_ref),
                    };
                }
                break :get_field result;
            },
            .@"struct" => decodeStruct(FieldType, field_ref),
        };
    }

    return result;
}

fn getFieldRef(table_ref: Ref, comptime id: u16) ?Ref {
    const vtable_ref = table_ref.soffset();
    const vtable_size = vtable_ref.decodeScalar(u16);
    // const object_size = vtable_ref.add(2).decodeScalar(u16);

    const vtable_entry_index = 2 + id;
    const vtable_entry_start = vtable_entry_index * @sizeOf(u16);
    const vtable_entry_end = vtable_entry_start + @sizeOf(u16);
    if (vtable_entry_end > vtable_size)
        return null;

    const field_offset = vtable_ref.add(vtable_entry_start).decodeScalar(u16);
    if (field_offset == 0)
        return null;

    return table_ref.add(field_offset);
}

pub fn decodeRoot(comptime T: type, data: []align(8) const u8) ValidationError!T {
    if (data.len < 8)
        return error.BufferTooSmall;

    const start = Ref{
        .ptr = data.ptr,
        .len = @truncate(data.len),
        .offset = 0,
    };

    try validateRoot(T, data);

    return .{ .@"#ref" = start.uoffset() };
}

// Validation errors
pub const ValidationError = error{
    BufferTooSmall,
    InvalidAlignment,
    InvalidOffset,
    Required,
    InvalidRef,
    InvalidVTableSize,
    InvalidEnumValue,
    InvalidUnionTag,
    StringNotNullTerminated,
    VectorLengthInvalid,
    InvalidUnion,
    InvalidBitFlags,
    InvalidString,
};

fn validateRoot(comptime T: type, data: []align(8) const u8) ValidationError!void {
    const schema: *const types.Schema = @field(T, "#root");
    const table_t: *const types.Table = @field(T, "#type");

    if (data.len < 8)
        return error.BufferTooSmall;

    const start = Ref{
        .ptr = data.ptr,
        .len = @truncate(data.len),
        .offset = 0,
    };

    // Validate root offset
    const root_table_ref = try validateUOffset(start);

    // Validate the root table
    try validateTableRef(schema, table_t, root_table_ref);
}

fn validateUOffset(ref: Ref) ValidationError!Ref {
    if (ref.offset % 4 != 0)
        return error.InvalidAlignment;

    if (ref.offset + @sizeOf(u32) > ref.len)
        return error.InvalidOffset;

    var result: u64 = @intCast(ref.offset);
    result += @intCast(ref.decodeScalar(u32));

    if (result >= ref.len)
        return error.InvalidOffset;

    return .{ .ptr = ref.ptr, .len = ref.len, .offset = @intCast(result) };
}

fn validateSOffset(ref: Ref) ValidationError!Ref {
    if (ref.offset % 4 != 0)
        return error.InvalidAlignment;

    if (ref.offset + @sizeOf(i32) > ref.len)
        return error.InvalidOffset;

    var result: i64 = @intCast(ref.offset);
    result -= ref.decodeScalar(i32);

    if (result < 0 or result >= ref.len)
        return error.InvalidOffset;

    return .{ .ptr = ref.ptr, .len = ref.len, .offset = @intCast(result) };
}

const VTable = struct {
    table_ref: Ref,
    table_size: u16,
    vtable_ref: Ref,
    vtable_size: u16,

    pub fn parse(table_ref: Ref) !VTable {
        // Validate table alignment
        if (table_ref.offset % 4 != 0)
            return error.InvalidAlignment;

        // Validate vtable offset
        const vtable_ref = try validateSOffset(table_ref);

        // Validate vtable size
        if (vtable_ref.offset + 2 * @sizeOf(u16) > vtable_ref.len)
            return error.InvalidOffset;

        const vtable_size = vtable_ref.decodeScalar(u16);
        const table_size = vtable_ref.add(@sizeOf(u16)).decodeScalar(u16);

        if (vtable_size < @sizeOf(u16) * 2 or vtable_size % 2 != 0)
            return error.InvalidVTableSize;

        if (vtable_ref.offset + vtable_size > vtable_ref.len)
            return error.InvalidVTableSize;

        if (table_size < 4)
            return error.InvalidVTableSize;

        return .{
            .table_ref = table_ref,
            .table_size = table_size,
            .vtable_ref = vtable_ref,
            .vtable_size = vtable_size,
        };
    }

    pub fn getFieldRef(self: VTable, field_id: u16) !?Ref {
        const vtable_entry_index = 2 + field_id;
        const vtable_entry_start = vtable_entry_index * @sizeOf(u16);
        const vtable_entry_end = vtable_entry_start + @sizeOf(u16);
        if (vtable_entry_end > self.vtable_size)
            return null;

        const field_offset = self.vtable_ref.add(vtable_entry_start).decodeScalar(u16);
        if (field_offset == 0)
            return null;

        if (field_offset < @sizeOf(u32) or field_offset >= self.table_size)
            return error.InvalidOffset;

        return self.table_ref.add(field_offset);
    }
};

fn validateTableRef(schema: *const types.Schema, table_t: *const types.Table, ref: Ref) ValidationError!void {
    const vtable = try VTable.parse(ref);

    var field_id: u16 = 0;
    for (table_t.fields) |field| {
        switch (field.type) {
            .@"union" => |union_ref| {
                defer field_id += 2;

                const field_tag_ref = try vtable.getFieldRef(field_id) orelse
                    if (field.required) {
                        return error.Required;
                    } else continue;

                if (field_tag_ref.offset + @sizeOf(u8) > ref.len)
                    return error.InvalidOffset;

                const tag_value = field_tag_ref.decodeScalar(u8);
                if (tag_value == 0)
                    continue;

                const union_t = try schema.getUnion(union_ref);
                if (tag_value > union_t.options.len)
                    return error.InvalidUnionTag;

                const option = union_t.options[tag_value - 1];
                const option_t = try schema.getTable(option.table);

                const field_ref = try vtable.getFieldRef(field_id + 1) orelse
                    return error.InvalidUnion;

                const field_table_ref = try validateUOffset(field_ref);
                try validateTableRef(schema, option_t, field_table_ref);
            },
            else => {
                defer field_id += 1;

                const field_ref = try vtable.getFieldRef(field_id) orelse
                    if (field.required) {
                        return error.Required;
                    } else continue;

                switch (field.type) {
                    .bool => try validateScalar(1, field_ref),
                    .int => |int_t| try validateScalar(int_t.getSize(), field_ref),
                    .float => |float_t| try validateScalar(float_t.getSize(), field_ref),
                    .@"enum" => |enum_ref| {
                        const field_t = try schema.getEnum(enum_ref);
                        try validateEnum(field_t, field_ref);
                    },
                    .bit_flags => |bit_flags_ref| {
                        const field_t = try schema.getBitFlags(bit_flags_ref);
                        try validateBitFlags(field_t, field_ref);
                    },
                    .string => try validateString(field_ref),
                    .table => |table_ref| {
                        const field_t = try schema.getTable(table_ref);
                        const field_table_ref = try validateUOffset(field_ref);
                        try validateTableRef(schema, field_t, field_table_ref);
                    },
                    .@"union" => unreachable,
                    .vector => |vector_t| try validateVector(schema, vector_t, field_ref),
                    .@"struct" => |struct_ref| {
                        const struct_t = try schema.getStruct(struct_ref);
                        try validateStruct(schema, struct_t, field_ref);
                    },
                }
            },
        }
    }
}

inline fn validateScalar(size: u32, ref: Ref) ValidationError!void {
    if (ref.offset + size > ref.len)
        return error.InvalidOffset;
}

fn validateEnum(enum_t: *const types.Enum, ref: Ref) ValidationError!void {
    try validateScalar(enum_t.backing_integer.getSize(), ref);
    const value = decodeInteger(enum_t.backing_integer, ref);
    try validateEnumValue(enum_t, value);
}

fn validateEnumValue(enum_t: *const types.Enum, value: i64) !void {
    for (enum_t.values) |enum_value|
        if (enum_value.value == value)
            return;

    return error.InvalidEnumValue;
}

fn decodeInteger(int_t: types.Integer, ref: Ref) i64 {
    return switch (int_t) {
        .i8 => ref.decodeScalar(i8),
        .u8 => ref.decodeScalar(u8),
        .i16 => ref.decodeScalar(i16),
        .u16 => ref.decodeScalar(u16),
        .i32 => ref.decodeScalar(i32),
        .u32 => ref.decodeScalar(u32),
        .i64 => ref.decodeScalar(i64),
        .u64 => @intCast(ref.decodeScalar(u64)),
    };
}

fn validateBitFlags(bit_flags_t: *const types.BitFlags, ref: Ref) ValidationError!void {
    try validateScalar(bit_flags_t.backing_integer.getSize(), ref);
    var value: u64 = switch (bit_flags_t.backing_integer) {
        .u8 => ref.decodeScalar(u8),
        .u16 => ref.decodeScalar(u16),
        .u32 => ref.decodeScalar(u32),
        .u64 => ref.decodeScalar(u64),
        else => return error.InvalidBitFlags,
    };

    for (bit_flags_t.fields) |field|
        value &= std.math.maxInt(u64) ^ field.value;

    if (value != 0)
        return error.InvalidBitFlags;
}

fn validateStruct(schema: *const types.Schema, struct_t: *const types.Struct, ref: Ref) ValidationError!void {
    _ = schema;
    _ = struct_t;
    _ = ref;
}

fn validateString(item_ref: Ref) ValidationError!void {
    const str_ref = try validateUOffset(item_ref);

    if (str_ref.offset + @sizeOf(u32) > str_ref.len)
        return error.InvalidOffset;

    const str_len = str_ref.decodeScalar(u32);
    const str_start = str_ref.offset + @sizeOf(u32);
    const str_end = str_start + str_len;

    if (str_end >= str_ref.len) // >= because we need room for null terminator
        return error.InvalidOffset;

    // Validate null terminator
    if (str_ref.ptr[str_end] != 0)
        return error.InvalidString;
}

fn validateVector(schema: *const types.Schema, vector_t: types.Vector, ref: Ref) ValidationError!void {
    const vec_ref = try validateUOffset(ref);

    try validateScalar(@sizeOf(u32), vec_ref);
    const vec_len = vec_ref.decodeScalar(u32);

    const element_size = try vector_t.element.getSize(schema);
    try validateScalar(@sizeOf(u32) + element_size * vec_len, vec_ref);

    switch (vector_t.element) {
        .bool, .int, .float => {},
        .@"enum" => |enum_ref| {
            const field_t = try schema.getEnum(enum_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + element_size * @as(u32, @intCast(i)));
                try validateEnum(field_t, element_ref);
            }
        },
        .@"struct" => |struct_ref| {
            const struct_t = try schema.getStruct(struct_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + element_size * @as(u32, @intCast(i)));
                try validateStruct(schema, struct_t, element_ref);
            }
        },
        .bit_flags => |bit_flags_ref| {
            const field_t = try schema.getBitFlags(bit_flags_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + element_size * @as(u32, @intCast(i)));
                try validateBitFlags(field_t, element_ref);
            }
        },
        .table => |table_ref| {
            const field_t = try schema.getTable(table_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + element_size * @as(u32, @intCast(i)));
                const element_table_ref = try validateUOffset(element_ref);
                try validateTableRef(schema, field_t, element_table_ref);
            }
        },
        .string => {
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + element_size * @as(u32, @intCast(i)));
                try validateString(element_ref);
            }
        },
    }
}
