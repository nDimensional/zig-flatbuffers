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
        result +|= offset;
        if (result > ref.len)
            @panic("unsigned offset overflow");
        return .{ .ptr = ref.ptr, .len = ref.len, .offset = @intCast(result) };
    }

    pub inline fn sub(ref: Ref, offset: i32) Ref {
        var result: i64 = @intCast(ref.offset);
        result -|= offset;
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

    pub inline fn format(self: Ref, writer: *std.Io.Writer) !void {
        try writer.print("{*}[0x{x:0>8}]", .{ self.ptr, self.offset });
    }
};

/// Used to differentiate the kinds of declarations
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
        const item_size = getVectorElementSize(T);

        const Self = @This();

        @"#ref": Ref,

        pub inline fn len(self: Self) usize {
            return self.@"#ref".decodeScalar(u32);
        }

        pub fn get(self: Self, index: usize) T {
            const i: u32 = @truncate(index);
            const item_ref = self.@"#ref".add(@sizeOf(u32) + item_size * i);
            return switch (@typeInfo(T)) {
                .int, .float, .bool => item_ref.decodeScalar(T),
                .pointer => decodeString(item_ref),
                .@"enum" => item_ref.decodeEnum(T),
                .@"struct" => switch (@field(T, "#kind")) {
                    Kind.Table => decodeTable(T, item_ref),
                    Kind.Struct => decodeStruct(T, item_ref),
                    Kind.BitFlags => decodeBitFlags(T, item_ref),
                    Kind.Vector => @compileError("cannot nest vectors"),
                    Kind.Union, Kind.Enum => @compileError("invalid struct declaration"),
                },
                else => @compileError("invalid vector type"),
            };
        }

        pub const Iterator = struct {
            vector: Self,
            index: usize = 0,

            pub fn next(self: *Iterator) ?T {
                if (self.index >= self.vector.len())
                    return null;
                defer self.index += 1;
                return self.vector.get(self.index);
            }
        };

        pub inline fn iterator(self: Self) Iterator {
            return .{ .vector = self };
        }
    };
}

// fn getVectorType(comptime T: type) types.Vector {
//     const element = switch (@typeInfo(T)) {
//         .bool => types.Vector.Element.bool,
//         .int => |info| types.Vector.Element{
//             .int = switch (info.bits) {
//                 8 => if (info.signed) .i8 else .u8,
//                 16 => if (info.signed) .i16 else .u16,
//                 32 => if (info.signed) .i32 else .u32,
//                 64 => if (info.signed) .i64 else .u64,
//                 else => @compileError("invalid integer type"),
//             },
//         },
//         .float => |info| types.Vector.Element{
//             .float = switch (info.bits) {
//                 32 => .f32,
//                 64 => .f64,
//             },
//         },
//         .pointer => types.Vector.Element.string,
//         .@"enum" => types.Vector.Element{
//             .@"enum" = .{ .name = @as(*const types.Enum, @field(T, "#type")).name },
//         },
//         .@"struct" => switch (@field(T, "#kind")) {
//             Kind.Table => types.Vector.Element{
//                 .table = .{ .name = @as(*const types.Table, @field(T, "#type")).name },
//             },
//             Kind.Vector => @compileError("cannot nest vectors"),
//             Kind.Struct => types.Vector.Element{
//                 .@"struct" = .{ .name = @as(*const types.Struct, @field(T, "#type")).name },
//             },
//             Kind.BitFlags => types.Vector.Element{
//                 .bit_flags = .{ .name = @as(*const types.BitFlags, @field(T, "#type")).name },
//             },
//             Kind.Union, Kind.Enum => @compileError("invalid struct declaration"),
//         },
//         else => @compileError("invalid vector type"),
//     };

//     return types.Vector{ .element = element };
// }

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
                const bit_flags: *const types.BitFlags = @field(T, "#type");
                return bit_flags.backing_integer.getSize();
            },
            Kind.Union, Kind.Enum => @compileError("invalid vector type"),
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
        .@"union" => |info| info.tag_type,
        else => @compileError("expected tagged union type"),
    } orelse @compileError("expected tagged union type");

    const tag_info = switch (@typeInfo(tag_type)) {
        .@"enum" => |info| info,
        else => @compileError("expected enum tag type"),
    };

    const tag_field_ref = getFieldRef(table_ref, tag_id) orelse
        return @unionInit(T, "NONE", {});

    const data = tag_field_ref.ptr[tag_field_ref.offset..tag_field_ref.len][0..@sizeOf(tag_type)];
    const tag_value = std.mem.readInt(tag_info.tag_type, data, .little);

    if (tag_value == 0)
        return @unionInit(T, "NONE", {});

    const ref_field_ref = getFieldRef(table_ref, ref_id) orelse
        return @unionInit(T, "NONE", {});

    const ref_ref = ref_field_ref.uoffset();

    inline for (tag_info.fields) |tag_field| {
        if (tag_field.value > 0 and tag_field.value == tag_value) {
            return @unionInit(T, tag_field.name, .{ .@"#ref" = ref_ref });
        }
    }

    return @unionInit(T, "NONE", {});
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

    const bit_flags: *const types.BitFlags = comptime @field(T, "#type");

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

    const struct_t: *const types.Struct = comptime @field(T, "#type");

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

    try validateScalar(@sizeOf(u32) + vector_t.element_size * vec_len, vec_ref);

    switch (vector_t.element) {
        .bool, .int, .float => {},
        .@"enum" => |enum_ref| {
            const field_t = try schema.getEnum(enum_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + vector_t.element_size * @as(u32, @intCast(i)));
                try validateEnum(field_t, element_ref);
            }
        },
        .@"struct" => |struct_ref| {
            const struct_t = try schema.getStruct(struct_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + vector_t.element_size * @as(u32, @intCast(i)));
                try validateStruct(schema, struct_t, element_ref);
            }
        },
        .bit_flags => |bit_flags_ref| {
            const field_t = try schema.getBitFlags(bit_flags_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + vector_t.element_size * @as(u32, @intCast(i)));
                try validateBitFlags(field_t, element_ref);
            }
        },
        .table => |table_ref| {
            const field_t = try schema.getTable(table_ref);
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + vector_t.element_size * @as(u32, @intCast(i)));
                const element_table_ref = try validateUOffset(element_ref);
                try validateTableRef(schema, field_t, element_table_ref);
            }
        },
        .string => {
            for (0..vec_len) |i| {
                const element_ref = vec_ref.add(@sizeOf(u32) + vector_t.element_size * @as(u32, @intCast(i)));
                try validateString(element_ref);
            }
        },
    }
}

fn writeScalar(comptime T: type, slot: *[@sizeOf(T)]u8, value: T) void {
    switch (@typeInfo(T)) {
        .bool => slot[0] = if (value) 1 else 0,
        .int => std.mem.writeInt(T, slot, value, .little),
        .float => |float| switch (float.bits) {
            32 => std.mem.writeInt(u32, slot, @bitCast(value), .little),
            64 => std.mem.writeInt(u64, slot, @bitCast(value), .little),
            else => @compileError("invalid float type"),
        },
        .@"enum" => |enum_t| std.mem.writeInt(enum_t.tag_type, slot, @intFromEnum(value), .little),
        else => @compileError("invalid scalar type"),
    }
}

fn writeStruct(comptime S: type, slot: []u8, value: S) void {
    const struct_t: *const types.Struct = @field(S, "#type");
    inline for (struct_t.fields) |field| {
        const F = @FieldType(S, field.name);
        const field_value: F = @field(value, field.name);
        const field_slot = slot[field.offset..];
        switch (field.type) {
            .bool, .int, .float => writeScalar(F, field_slot[0..@sizeOf(F)], field_value),
            .array => @compileError("not implemented"),
            .@"struct" => @compileError("not implemented"),
        }
    }
}

pub fn getBitFlagsValue(comptime T: type, flags: T) u64 {
    const bit_flags_t: *const types.BitFlags = @field(T, "#type");

    var value: u64 = 0;
    inline for (bit_flags_t.fields) |flag| {
        if (@field(flags, flag.name)) {
            value |= flag.value;
        }
    }

    return value;
}

pub const Builder = struct {
    // pub const block_size = std.heap.page_size_min;
    pub const block_size = 32;

    allocator: std.mem.Allocator,
    offset: i64,
    blocks: std.ArrayList([]align(8) u8),
    vtable: std.ArrayList(i64),
    field_refs: std.ArrayList(i64),
    vector_refs: std.ArrayList(i64),
    struct_buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) !Builder {
        var blocks = std.ArrayList([]align(8) u8).empty;
        errdefer blocks.deinit(allocator);

        const block = try allocator.alignedAlloc(u8, .@"8", Builder.block_size);
        errdefer allocator.free(block);

        try blocks.append(allocator, block);

        return .{
            .allocator = allocator,
            .offset = 0,
            .blocks = blocks,
            .vtable = std.ArrayList(i64).empty,
            .field_refs = std.ArrayList(i64).empty,
            .vector_refs = std.ArrayList(i64).empty,
            .struct_buffer = std.ArrayList(u8).empty,
        };
    }

    pub fn deinit(self: *Builder) void {
        for (self.blocks.items) |block|
            self.allocator.free(block);
        self.blocks.deinit(self.allocator);
        self.vtable.deinit(self.allocator);
        self.field_refs.deinit(self.allocator);
        self.vector_refs.deinit(self.allocator);
        self.struct_buffer.deinit(self.allocator);
        self.offset = 0;
    }

    inline fn capacity(self: *const Builder) i64 {
        return @intCast(self.blocks.items.len * block_size);
    }

    fn alloc(
        self: *Builder,
        comptime size: u32,
        comptime alignment: u32,
    ) !*align(alignment) [size]u8 {
        comptime {
            if (size > Builder.block_size) @compileError("alloc size too large");
        }

        self.offset = std.mem.alignBackward(i64, self.offset, alignment);
        self.offset -= size;

        var head_offset = self.capacity() + self.offset;
        while (head_offset < 0) : (head_offset += block_size)
            try self.prepend();

        const head = self.blocks.items[0];
        return @alignCast(head[@intCast(head_offset)..][0..size]);
    }

    inline fn fromSOffset(self: *const Builder, soffset: i64) Ref {
        const uoffset: u32 = @intCast(self.capacity() + soffset);
        const block_index = @divTrunc(uoffset, block_size);
        const block_offset = @mod(uoffset, block_size);
        const block = self.blocks.items[block_index];
        return Ref{
            .ptr = block.ptr,
            .len = @truncate(block.len),
            .offset = block_offset,
        };
    }

    inline fn toSOffset(self: *const Builder, ref: Ref) i64 {
        var offset: i64 = 0;
        for (0..self.blocks.items.len) |i| {
            const j = self.blocks.items.len - i - 1;
            const block = self.blocks.items[j];
            if (block.ptr == ref.ptr) {
                return offset - (block_size - ref.offset);
            } else {
                offset -= block_size;
            }
        }

        @panic("invalid ref");
    }

    fn prepend(self: *Builder) !void {
        const block = try self.allocator.alignedAlloc(u8, .@"8", Builder.block_size);
        errdefer self.allocator.free(block);
        try self.blocks.insert(self.allocator, 0, block);
    }

    inline fn getUOffset(self: *const Builder, ref: Ref) u32 {
        const soffset = self.toSOffset(ref);
        if (soffset < self.offset)
            @panic("invalid ref");

        return @intCast(soffset - self.offset);
    }

    fn writeBytes(self: *Builder, value: []const u8, offset: i64) !void {
        const total_size = self.capacity();
        var written: usize = 0;

        const offset_start: usize = @intCast(total_size + offset);

        const offset_end = offset_start + value.len;
        const block_index_start = try std.math.divFloor(usize, offset_start, block_size);
        const block_index_end = try std.math.divCeil(usize, offset_end, block_size);

        for (block_index_start..block_index_end) |block_index| {
            const block = self.blocks.items[block_index];
            const block_start = block_index * block_size;
            const chunk_start = @mod(@max(offset_start, block_start), block_size);
            const chunk_end = @min(block_size, offset_end - block_start);
            const chunk_len = chunk_end - chunk_start;

            @memcpy(block[chunk_start..chunk_end], value[written .. written + chunk_len]);
            written += chunk_len;
        }

        std.debug.assert(written == value.len);
    }

    fn writeString(self: *Builder, value: []const u8) !i64 {
        const value_len: i64 = @intCast(value.len);

        self.offset = std.mem.alignBackward(i64, self.offset - value_len - 1, @sizeOf(u32));
        self.offset -= @sizeOf(u32);

        while (self.capacity() + self.offset < 0)
            try self.prepend();

        const head_start: usize = @intCast(self.capacity() + self.offset);
        writeScalar(u32, self.blocks.items[0][head_start..][0..@sizeOf(u32)], @truncate(value.len));

        const value_offset = self.offset + @sizeOf(u32);
        try self.writeBytes(value, value_offset);
        try self.writeBytes(&.{0}, value_offset + value_len);

        return self.offset;
    }

    fn Unwrap(comptime T: type) type {
        return switch (@typeInfo(T)) {
            .optional => |info| info.child,
            else => T,
        };
    }

    fn Wrap(comptime T: type) type {
        return switch (@typeInfo(T)) {
            .optional => T,
            else => @Type(.{ .optional = .{ .child = T } }),
        };
    }

    fn wrap(value: anytype) Wrap(@TypeOf(value)) {
        return switch (@typeInfo(@TypeOf(value))) {
            .optional => value,
            else => @as(?@TypeOf(value), value),
        };
    }

    fn getUnionRef(comptime T: type, value: T) ?struct { tag: u8, ref: Ref } {
        const fields = switch (@typeInfo(T)) {
            .@"union" => |info| info.fields,
            else => @compileError("expected union type"),
        };

        if (value == .NONE)
            return null;

        inline for (fields[1..], 1..) |field, tag| {
            if (std.mem.eql(u8, field.name, @tagName(value))) {
                const active_field = @field(value, field.name);
                return .{ .tag = tag, .ref = @field(active_field, "#ref") };
            }
        }

        return null;
    }

    pub fn writeTable(self: *Builder, comptime T: type, fields: @field(T, "#constructor")) !T {
        if (@field(T, "#kind") != Kind.Table)
            @compileError("invalid table type");

        const t: *const types.Table = @field(T, "#type");

        var field_id: u16 = 0;
        for (t.fields) |field| {
            switch (field.type) {
                .@"union" => field_id += 2,
                else => field_id += 1,
            }
        }

        // The first thing we need to do is iterate over the fields,
        // write out any string and vector values, and save refs to them.
        try self.field_refs.resize(self.allocator, field_id);
        defer self.field_refs.clearRetainingCapacity();
        @memset(self.field_refs.items, 0);

        field_id = 0;
        inline for (t.fields) |field| {
            defer switch (field.type) {
                .@"union" => field_id += 2,
                else => field_id += 1,
            };

            if (!field.deprecated) {
                switch (field.type) {
                    .string => if (wrap(@field(fields, field.name))) |value| {
                        self.field_refs.items[field_id] = try self.writeString(value);
                    },
                    .vector => |vector_t| if (wrap(@field(fields, field.name))) |value| {
                        const vector_len: u32 = @truncate(vector_t.element_size * value.len);

                        switch (vector_t.element) {
                            .bool, .int, .float, .@"enum" => {
                                self.offset = std.mem.alignBackward(i64, self.offset - vector_len, vector_t.minalign);
                                while (self.capacity() + self.offset < 0)
                                    try self.prepend();

                                const vector_start: usize = @intCast(@mod(self.offset, self.capacity()));
                                for (value, 0..) |item, i| {
                                    const item_offset = vector_start + i * vector_t.element_size;
                                    const block_index = @divFloor(item_offset, block_size);
                                    const block_offset = @mod(item_offset, block_size);
                                    const slot = self.blocks.items[block_index][block_offset..][0..vector_t.element_size];
                                    writeScalar(@TypeOf(item), slot, item);
                                }

                                // for (0..value.len) |i| {
                                //     const j = value.len - i - 1;
                                //     const item = value[j];
                                //     const item_slot = try self.alloc(vector_t.element_size, vector_t.element_size);
                                //     writeScalar(@TypeOf(item), item_slot, item);
                                // }
                            },
                            .@"struct" => {
                                try self.struct_buffer.resize(self.allocator, vector_t.element_size);
                                defer self.struct_buffer.clearRetainingCapacity();

                                self.offset = std.mem.alignBackward(i64, self.offset - vector_len, vector_t.minalign);
                                while (self.capacity() + self.offset < 0)
                                    try self.prepend();

                                for (value, 0..) |item, i| {
                                    writeStruct(@TypeOf(item), self.struct_buffer.items, item);
                                    const item_offset = self.offset + @as(i64, @intCast(vector_t.element_size * i));
                                    try self.writeBytes(self.struct_buffer.items, item_offset);
                                }

                                // for (0..value.len) |i| {
                                //     const j = value.len - i - 1;
                                //     const item = value[j];
                                //     const item_slot = try self.alloc(vector_t.element_size, alignment);
                                //     writeStruct(@TypeOf(item), item_slot, item);
                                // }
                            },
                            .bit_flags => @compileError("not implemented"),
                            .string => {
                                try self.vector_refs.resize(self.allocator, value.len);
                                defer self.vector_refs.clearRetainingCapacity();
                                for (value, 0..) |item, i|
                                    self.vector_refs.items[i] = try self.writeString(item);

                                for (0..value.len) |i| {
                                    const j = value.len - i - 1;
                                    const item_slot = try self.alloc(@sizeOf(u32), @sizeOf(u32));
                                    const ref = self.vector_refs.items[j];
                                    writeScalar(u32, item_slot, @intCast(ref - self.offset));
                                }
                            },
                            .table => {
                                for (0..value.len) |i| {
                                    const j = value.len - i - 1;
                                    const item = value[j];
                                    const item_slot = try self.alloc(@sizeOf(u32), @sizeOf(u32));
                                    const ref: Ref = @field(item, "#ref");
                                    writeScalar(u32, item_slot, self.getUOffset(ref));
                                }
                            },
                        }

                        std.debug.assert(@mod(self.offset, @sizeOf(u32)) == 0);
                        const len_slot = try self.alloc(@sizeOf(u32), @sizeOf(u32));
                        writeScalar(u32, len_slot, @truncate(value.len));
                        self.field_refs.items[field_id] = self.offset;
                    },
                    else => {},
                }
            }
        }

        try self.vtable.resize(self.allocator, field_id);
        defer self.vtable.clearRetainingCapacity();
        @memset(self.vtable.items, 0);

        const table_end = self.offset;

        field_id = 0;
        inline for (t.fields) |field| {
            defer switch (field.type) {
                .@"union" => field_id += 2,
                else => field_id += 1,
            };

            if (!field.deprecated) {
                const F = Unwrap(@FieldType(@field(T, "#constructor"), field.name));

                switch (field.type) {
                    .bool, .float, .int, .@"enum" => {
                        const field_value: F = @field(fields, field.name);
                        const slot = try self.alloc(@sizeOf(F), @sizeOf(F));
                        writeScalar(F, slot, field_value);
                        self.vtable.items[field_id] = self.offset;
                    },
                    .@"struct" => {
                        if (wrap(@field(fields, field.name))) |field_value| {
                            const struct_t: *const types.Struct = @field(F, "#type");

                            try self.struct_buffer.resize(self.allocator, struct_t.bytesize);
                            defer self.struct_buffer.clearRetainingCapacity();

                            writeStruct(F, self.struct_buffer.items, field_value);

                            self.offset = std.mem.alignBackward(i64, self.offset - struct_t.bytesize, struct_t.minalign);
                            while (self.capacity() + self.offset < 0)
                                try self.prepend();

                            try self.writeBytes(self.struct_buffer.items, self.offset);

                            self.vtable.items[field_id] = self.offset;
                        }
                    },
                    .bit_flags => {
                        if (@field(F, "#kind") != Kind.BitFlags)
                            @compileError("invalid bit flags type");

                        const bit_flags_t: *const types.BitFlags = @field(F, "#type");
                        const size = comptime bit_flags_t.backing_integer.getSize();

                        const field_value: F = @field(fields, field.name);
                        const flags = getBitFlagsValue(F, field_value);
                        if (flags != 0) {
                            const slot = try self.alloc(size, size);
                            switch (bit_flags_t.backing_integer) {
                                .u8 => std.mem.writeInt(u8, slot, @truncate(flags), .little),
                                .u16 => std.mem.writeInt(u16, slot, @truncate(flags), .little),
                                .u32 => std.mem.writeInt(u32, slot, @truncate(flags), .little),
                                .u64 => std.mem.writeInt(u64, slot, @truncate(flags), .little),
                                else => @compileError("invalid bit flags type"),
                            }

                            self.vtable.items[field_id] = self.offset;
                        }
                    },
                    .table, .vector, .string => {
                        if (wrap(@field(fields, field.name))) |field_value| {
                            const slot = try self.alloc(@sizeOf(u32), @sizeOf(u32));

                            const uoffset: u32 = switch (field.type) {
                                .table => self.getUOffset(@field(field_value, "#ref")),
                                .vector, .string => @intCast(self.field_refs.items[field_id] - self.offset),
                                else => unreachable,
                            };

                            writeScalar(u32, slot, uoffset);
                            self.vtable.items[field_id] = self.offset;
                        }
                    },
                    .@"union" => {
                        const field_value: F = @field(fields, field.name);
                        if (getUnionRef(F, field_value)) |entry| {
                            const tag_slot = try self.alloc(1, 1);
                            tag_slot[0] = entry.tag;
                            self.vtable.items[field_id] = self.offset;

                            const ref_slot = try self.alloc(@sizeOf(u32), @sizeOf(u32));
                            std.mem.writeInt(u32, ref_slot, self.getUOffset(entry.ref), .little);
                            self.vtable.items[field_id + 1] = self.offset;
                        }
                    },
                }
            }
        }

        // now we alloc the vtable soffset slot
        const vtable_soffset_slot = try self.alloc(@sizeOf(i32), @sizeOf(i32));
        const table_start = self.offset;

        const vtable_len = self.vtable.items.len;

        for (0..vtable_len) |i| {
            const vtable_slot = try self.alloc(@sizeOf(u16), @sizeOf(u16));

            const j = vtable_len - i - 1;
            if (self.vtable.items[j] != 0) {
                const field_uoffset: u16 = @intCast(self.vtable.items[j] - table_start);
                std.debug.assert(field_uoffset >= @sizeOf(i32));
                std.mem.writeInt(u16, vtable_slot, field_uoffset, .little);
            } else {
                std.mem.writeInt(u16, vtable_slot, 0, .little);
            }
        }

        const table_size_slot = try self.alloc(@sizeOf(u16), @sizeOf(u16));
        const table_size: u16 = @intCast(table_end - table_start);
        std.mem.writeInt(u16, table_size_slot, table_size, .little);

        const vtable_size_slot = try self.alloc(@sizeOf(u16), @sizeOf(u16));
        const vtable_size = @sizeOf(u16) * (2 + vtable_len);
        std.mem.writeInt(u16, vtable_size_slot, @truncate(vtable_size), .little);

        std.debug.assert(@as(i64, @intCast(vtable_size)) == table_start - self.offset);

        const vtable_soffset = @as(i32, @intCast(vtable_size));
        std.mem.writeInt(i32, vtable_soffset_slot, vtable_soffset, .little);

        return .{ .@"#ref" = self.fromSOffset(table_start) };
    }

    pub fn writeRoot(self: *Builder, comptime T: type, root: T) !void {
        if (@field(T, "#kind") != Kind.Table)
            @compileError("root value must be a table type");

        const root_slot = try self.alloc(@sizeOf(u32), @sizeOf(u32));
        const root_ref: Ref = @field(root, "#ref");

        const root_offset = self.getUOffset(root_ref);
        std.mem.writeInt(u32, root_slot, root_offset, .little);
    }

    pub fn write(self: *Builder, writer: *std.Io.Writer) !void {
        if (self.blocks.items.len == 0)
            return error.Empty;

        const head_offset: usize = @intCast(@mod(self.offset, block_size));
        const head = self.blocks.items[0];
        try writer.writeAll(head[head_offset..]);

        for (self.blocks.items[1..]) |block| {
            try writer.writeAll(block);
        }
    }

    pub fn writeAlloc(self: *Builder, allocator: std.mem.Allocator) ![]align(8) const u8 {
        const data = try allocator.alignedAlloc(u8, .@"8", @intCast(@abs(self.offset)));
        errdefer allocator.free(data);

        var writer = std.Io.Writer.fixed(data);
        try self.write(&writer);

        return data;
    }
};

// test "builder" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer std.debug.assert(gpa.deinit() == .ok);
//     const allocator = gpa.allocator();

//     var builder = try Builder.init(allocator);
//     defer builder.deinit();

//     const b = .{2} ** 119;
//     const b_ref = try builder.writeString(&b);
//     std.log.warn("got b_ref: {any}", .{b_ref});

//     const a = .{1} ** 12;
//     const a_ref = try builder.writeString(&a);
//     std.log.warn("got a_ref: {any}", .{a_ref});

//     std.log.warn("builder blocks: ({d}) offset {d}", .{ builder.blocks.items.len, builder.offset });
//     for (0..builder.blocks.items.len) |i| {
//         const block = builder.blocks.items[i];
//         std.log.warn("- {d} {*}", .{ i, block.ptr });
//         std.log.warn("  {x}", .{block});
//     }
// }
