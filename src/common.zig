const std = @import("std");

pub const Kind = union(enum) {
    pub const VectorInfo = struct {
        element: type,
    };

    pub const ArrayInfo = struct {
        element: type,
        size: comptime_int,
    };

    pub const BitFlagsInfo = struct {
        backing_integer: type,
        flags: []const comptime_int,
    };

    Table,
    Struct,
    Vector: VectorInfo,
    Array: ArrayInfo,
    BitFlags: BitFlagsInfo,
};

pub const String = [:0]const u8;

pub fn Array(comptime T: type, comptime size: comptime_int) type {
    return packed struct {
        pub const kind = Kind{ .Array = .{ .element = T, .size = size } };
    };
}

pub fn Vector(comptime T: type) type {
    return packed struct {
        pub const kind = Kind{ .Vector = .{ .element = T } };
        const item_size = getSize(T);

        const Self = @This();

        offset: u32,
        len: u32,

        pub fn in(self: Self, data: []const u8, index: usize) T {
            const start = self.offset + @sizeOf(u32);
            const i: u32 = @truncate(index);

            const item_offset = start + item_size * i;

            return switch (@typeInfo(T)) {
                .@"enum" => decodeEnum(T, data, item_offset),
                .@"struct" => switch (@field(T, "kind")) {
                    Kind.Table => decodeTable(T, data, item_offset),
                    Kind.Vector => @compileError("cannot nest vectors"),
                    Kind.Struct => @compileError("not implemented"),
                    Kind.Array => @compileError("not implemented"),
                    Kind.BitFlags => decodeBitFlags(T, data, item_offset),
                },
                .pointer => decodeString(data, item_offset),
                .int, .float, .bool => decodeScalar(T, data, item_offset),
                else => @compileError("not implemented"),
            };
        }
    };
}

fn getSize(comptime T: type) comptime_int {
    return switch (@typeInfo(T)) {
        .int, .float, .bool => @sizeOf(T),
        .pointer => @sizeOf(u32), // Strings
        .@"struct" => switch (@field(T, "kind")) {
            Kind.Table => @sizeOf(u32),
            Kind.Vector => @sizeOf(u32),
            Kind.Struct => @compileError("not implemented"),
            Kind.Array => @compileError("not implemented"),
            Kind.BitFlags => |bit_flags| @sizeOf(bit_flags.backing_integer),
        },

        else => @compileError("unexpected type"),
    };
}

fn getAlignment(comptime T: type) comptime_int {
    return switch (@typeInfo(T)) {
        .int, .float, .bool => @sizeOf(T),
        .pointer => @sizeOf(u32), // Strings
        .@"struct" => switch (@field(T, "kind")) {
            Kind.Table => @compileError("not implemented"),
            Kind.Vector => @compileError("not implemented"),
            Kind.Struct => @compileError("not implemented"),
            Kind.Array => @compileError("not implemented"),
            Kind.BitFlags => |bit_flags| @sizeOf(bit_flags.backing_integer),
        },

        else => @compileError("unexpected type"),
    };
}

pub inline fn decodeEnumField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return default;
    return decodeEnum(T, data, field_offset);
}

pub inline fn decodeScalarField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return default;
    return decodeScalar(T, data, field_offset);
}

pub inline fn decodeBitFlagsField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
    comptime default: T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return default;
    return decodeBitFlags(T, data, field_offset);
}

pub inline fn decodeTableField(comptime field_index: u16, comptime T: type, data: []const u8, table_offset: u32) ?T {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return null;
    return decodeTable(T, data, field_offset);
}

pub inline fn decodeStringField(
    comptime field_index: u16,
    data: []const u8,
    table_offset: u32,
) ?String {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return null;

    return decodeString(data, field_offset);
}

pub inline fn decodeVectorField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
) ?Vector(T) {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return null;

    return decodeVector(T, data, field_offset);
}

fn decodeEnum(comptime T: type, data: []const u8, offset: u32) T {
    const info = switch (@typeInfo(T)) {
        .@"enum" => |info| info,
        else => @panic("invalid enum type"),
    };

    const value = std.mem.readInt(
        info.tag_type,
        data[offset..][0..@sizeOf(info.tag_type)],
        .little,
    );

    return @enumFromInt(value);
}

fn decodeScalar(comptime T: type, data: []const u8, offset: u32) T {
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

fn decodeBitFlags(comptime T: type, data: []const u8, offset: u32) T {
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

fn decodeVector(comptime T: type, data: []const u8, offset: u32) Vector(T) {
    const vec_start_offset = decodeScalar(u32, data, offset);
    const vec_offset = offset + vec_start_offset;
    const vec_len = decodeScalar(u32, data, vec_offset);
    return Vector(T){ .offset = vec_offset, .len = vec_len };
}

inline fn decodeString(data: []const u8, offset: u32) String {
    const str_offset = offset + decodeScalar(u32, data, offset);
    const str_len = decodeScalar(u32, data, str_offset);
    return data[str_offset + @sizeOf(u32) ..][0..str_len :0];
}

inline fn decodeTable(comptime T: type, data: []const u8, offset: u32) T {
    const table_offset = offset + decodeScalar(u32, data, offset);
    return T{ .offset = table_offset };
}

inline fn getVTableOffset(data: []const u8, table_offset: u32) u32 {
    const vtable_soffset = decodeScalar(i32, data, table_offset);
    const vtable_uoffset = @as(i32, @intCast(table_offset)) - vtable_soffset;
    return @intCast(vtable_uoffset);
}

fn getFieldOffset(data: []const u8, table_offset: u32, comptime field_index: u16) ?u32 {
    const vtable_offset = getVTableOffset(data, table_offset);
    const vtable_size = decodeScalar(u16, data, vtable_offset);

    const vtable_entry_offset_bytes = (2 + field_index) * @sizeOf(u16);
    if (vtable_entry_offset_bytes + @sizeOf(u16) <= vtable_size) {
        const vtable_entry = decodeScalar(u16, data, vtable_offset + vtable_entry_offset_bytes);
        if (vtable_entry > 0) {
            return table_offset + vtable_entry;
        }
    }

    return null;
}
