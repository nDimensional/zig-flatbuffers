const std = @import("std");

pub const Kind = union(enum) {
    pub const VectorInfo = struct {
        element: type,
    };

    pub const BitFlagsInfo = struct {
        backing_integer: type,
        flags: []const comptime_int,
    };

    Table,
    Vector: VectorInfo,
    BitFlags: BitFlagsInfo,
};

pub const Buffer = []align(8) const u8;

pub const String = [:0]const u8;

pub fn Vector(comptime T: type) type {
    return packed struct {
        pub const kind = Kind{ .Vector = .{ .element = T } };
        const item_size = getVectorElementSize(T);

        const Self = @This();

        offset: u32,
        len: u32,

        pub fn in(self: Self, data: Buffer, index: usize) T {
            const start = self.offset + @sizeOf(u32);
            const i: u32 = @truncate(index);

            const item_offset = start + item_size * i;

            return switch (@typeInfo(T)) {
                .@"enum" => decodeEnum(T, data, item_offset),
                .@"struct" => |info| switch (info.layout) {
                    .auto => {
                        //
                    },
                    .@"packed" => switch (@field(T, "kind")) {
                        Kind.Table => decodeTable(T, data, item_offset),
                        Kind.Vector => @compileError("cannot nest vectors"),
                        Kind.BitFlags => decodeBitFlags(T, data, item_offset),
                    },
                    else => @compileError("invalid struct layout"),
                },
                .pointer => decodeString(data, item_offset),
                .int, .float, .bool => decodeScalar(T, data, item_offset),
                else => @compileError("not implemented"),
            };
        }
    };
}

fn getVectorElementSize(comptime T: type) u32 {
    return switch (@typeInfo(T)) {
        .int, .float, .bool => @sizeOf(T),
        .pointer => @sizeOf(u32), // Strings
        .@"struct" => |info| switch (info.layout) {
            .auto => getStructSize(T),
            .@"packed" => switch (@field(T, "kind")) {
                Kind.Table => @sizeOf(u32),
                Kind.Vector => @sizeOf(u32),
                Kind.BitFlags => |bit_flags| @sizeOf(bit_flags.backing_integer),
            },
            else => @compileError("invalid struct layout"),
        },

        else => @compileError("unexpected type"),
    };
}

pub fn getStructAlignment(comptime T: type) u32 {
    switch (@typeInfo(T)) {
        .int, .float, .bool => return @sizeOf(T),
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

pub fn getStructSize(comptime T: type) u32 {
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

pub inline fn decodeScalarField(
    comptime T: type,
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return default;
    return decodeScalar(T, data, field_offset);
}

pub inline fn decodeEnumField(
    comptime T: type,
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return default;
    return decodeEnum(T, data, field_offset);
}

pub inline fn decodeBitFlagsField(
    comptime T: type,
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return default;
    return decodeBitFlags(T, data, field_offset);
}

pub fn decodeStructField(
    comptime T: type,
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return default;
    return decodeEnum(T, data, field_offset);
}

pub inline fn decodeTableField(
    comptime T: type,
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
) ?T {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return null;
    return decodeTable(T, data, field_offset);
}

pub inline fn decodeUnionField(
    comptime T: type,
    comptime tag_field_id: u16,
    comptime ref_field_id: u16,
    data: Buffer,
    table_offset: u32,
) T {
    const tag_type: type = switch (@typeInfo(T)) {
        .@"union" => |info| info.tag_type orelse
            @compileError("expected tagged union type"),
        else => @compileError("expected tagged union type"),
    };

    const tag_fields = switch (@typeInfo(tag_type)) {
        .@"enum" => |info| info.fields,
        else => @compileError("expected enum tag type"),
    };

    const tag_field_offset = getFieldOffset(data, table_offset, tag_field_id) orelse
        return @unionInit(T, "NONE", {});

    const tag_value = std.mem.readInt(
        tag_type,
        data[tag_field_offset..][0..@sizeOf(tag_type)],
        .little,
    );

    if (tag_value == 0)
        return @unionInit(T, "NONE", {});

    const ref_field_offset = getFieldOffset(data, table_offset, ref_field_id) orelse
        return @unionInit(T, "NONE", {});

    const ref_offset = ref_field_offset + decodeScalar(u32, data, ref_field_offset);

    inline for (tag_fields) |tag_field| {
        if (tag_field.value == tag_value) {
            return @unionInit(T, tag_field.name, .{ .offset = ref_offset });
        }
    }
}

pub inline fn decodeVectorField(
    comptime T: type,
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
) ?Vector(T) {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return null;

    return decodeVector(T, data, field_offset);
}

pub inline fn decodeStringField(
    comptime field_id: u16,
    data: Buffer,
    table_offset: u32,
) ?String {
    const field_offset = getFieldOffset(data, table_offset, field_id) orelse
        return null;

    return decodeString(data, field_offset);
}

inline fn decodeEnum(comptime T: type, data: Buffer, offset: u32) T {
    const info = switch (@typeInfo(T)) {
        .@"enum" => |info| info,
        else => @compileError("invalid enum type"),
    };

    const value = std.mem.readInt(
        info.tag_type,
        data[offset..][0..@sizeOf(info.tag_type)],
        .little,
    );

    return @enumFromInt(value);
}

inline fn decodeScalar(comptime T: type, data: Buffer, offset: u32) T {
    return switch (@typeInfo(T)) {
        .int => |info| switch (info.bits) {
            8, 16, 32, 64 => std.mem.readInt(T, data[offset..][0..@sizeOf(T)], .little),
            else => @compileError("only 8, 16, 32, and 64-bit integers are supported"),
        },
        .float => |info| switch (info.bits) {
            32 => @bitCast(std.mem.readInt(u32, data[offset..][0..@sizeOf(T)], .little)),
            64 => @bitCast(std.mem.readInt(u64, data[offset..][0..@sizeOf(T)], .little)),
            else => @compileError("only 32 and 64bit floats are supported"),
        },
        .bool => data[offset] != 0,
        else => @compileError("expected scalar value"),
    };
}

inline fn decodeBitFlags(comptime T: type, data: Buffer, offset: u32) T {
    const info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError("expected bit flags struct"),
    };

    const bit_flags = switch (@field(T, "kind")) {
        Kind.BitFlags => |bit_flags| bit_flags,
        else => @compileError("expected bit flags struct"),
    };

    if (bit_flags.flags.len != info.fields.len)
        @compileError("invalid bit flag fields");

    const value: bit_flags.backing_integer = std.mem.readInt(
        bit_flags.backing_integer,
        data[offset..][0..@sizeOf(bit_flags.backing_integer)],
        .little,
    );

    var result: T = .{};
    inline for (info.fields, bit_flags.flags) |field, flag| {
        if (field.type != bool)
            @compileError("invalid bit flag fields");

        @field(result, field.name) = value & flag != 0;
    }

    return result;
}

// fn decodeStruct(comptime T: type, data: Buffer, offset: u32) T {
//     //
// }

fn decodeVector(comptime T: type, data: Buffer, offset: u32) Vector(T) {
    const vec_start_offset = decodeScalar(u32, data, offset);
    const vec_offset = offset + vec_start_offset;
    const vec_len = decodeScalar(u32, data, vec_offset);
    return Vector(T){ .offset = vec_offset, .len = vec_len };
}

inline fn decodeString(data: Buffer, offset: u32) String {
    const str_offset = offset + decodeScalar(u32, data, offset);
    const str_len = decodeScalar(u32, data, str_offset);
    return data[str_offset + @sizeOf(u32) ..][0..str_len :0];
}

inline fn decodeTable(comptime T: type, data: Buffer, offset: u32) T {
    const table_offset = offset + decodeScalar(u32, data, offset);
    return T{ .offset = table_offset };
}

inline fn getVTableOffset(data: Buffer, table_offset: u32) u32 {
    const vtable_soffset = decodeScalar(i32, data, table_offset);
    const vtable_uoffset = @as(i32, @intCast(table_offset)) - vtable_soffset;
    return @intCast(vtable_uoffset);
}

fn getFieldOffset(data: Buffer, table_offset: u32, comptime field_id: u16) ?u32 {
    const vtable_offset = getVTableOffset(data, table_offset);
    const vtable_size = decodeScalar(u16, data, vtable_offset);

    const vtable_entry_offset_bytes = (2 + field_id) * @sizeOf(u16);
    if (vtable_entry_offset_bytes + @sizeOf(u16) <= vtable_size) {
        const vtable_entry = decodeScalar(u16, data, vtable_offset + vtable_entry_offset_bytes);
        if (vtable_entry > 0) {
            return table_offset + vtable_entry;
        }
    }

    return null;
}
