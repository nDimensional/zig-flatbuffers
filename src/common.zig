const std = @import("std");

const BitFlags = struct {
    backing_integer: type,
    flags: []const comptime_int,
};

pub const Kind = union(enum) {
    Table,
    Struct,
    Vector: type,
    Array: type,
    BitFlags: BitFlags,
};

pub const String = [:0]const u8;

pub fn Vector(comptime T: type) type {
    return struct {
        pub const kind = Kind.vector(T);

        const Self = @This();

        offset: u32,
        len: u32,

        pub fn in(self: Self, data: []const u8, index: u32) T {
            const start = self.offset + @sizeOf(u32);
            switch (@typeInfo(T)) {
                .@"enum" => @compileError("not implemented"),
                .@"struct" => switch (@field(T, "kind")) {
                    .Table => {
                        const item_offset = start + @sizeOf(u32) * index;
                        return decodeTable(T, data, item_offset);
                    },
                    .Vector => @compileError("cannot nest vectors"),
                    .Struct, .Array, .BitFlags => @compileError("not implemented"),
                },
                .pointer => {
                    const item_offset = start + @sizeOf(u32) * index;
                    return decodeString(data, item_offset);
                },
                .int, .float, .bool => {
                    const item_offset = start + @sizeOf(T) * index;
                    return decodeScalar(T, data, item_offset);
                },
                else => @compileError("not implemented"),
            }

            @compileError("not implemented");
        }
    };
}

pub inline fn decodeEnumField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
    comptime default: ?T,
) !T {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return default orelse defaultEnumValue(T);
    return try decodeEnum(T, data, field_offset);
}

pub inline fn decodeScalarField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
    comptime default: ?T,
) T {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return default orelse defaultScalarValue(T);
    return decodeScalar(T, data, field_offset);
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

pub fn decodeVectorField(
    comptime field_index: u16,
    comptime T: type,
    data: []const u8,
    table_offset: u32,
) ?Vector(T) {
    const field_offset = getFieldOffset(data, table_offset, field_index) orelse
        return null;

    return decodeVector(T, data, field_offset);
}

pub fn decodeEnum(comptime T: type, data: []const u8, offset: u32) !T {
    const info = switch (@typeInfo(T)) {
        .@"enum" => |info| info,
        else => @compileError("expected enum type"),
    };

    const value = std.mem.readInt(
        info.tag_type,
        data[offset..][0..@sizeOf(info.tag_type)],
        .little,
    );

    const fields = info.fields.ptr[0..info.fields.len];
    inline for (fields) |field| {
        if (field.value == value)
            return @enumFromInt(value);
    }

    return error.InvalidEnumValue;
}

pub fn defaultEnumValue(comptime T: type) !T {
    const info = switch (@typeInfo(T)) {
        .@"enum" => |info| info,
        else => @compileError("expected enum type"),
    };

    const fields = info.fields.ptr[0..info.fields.len];
    inline for (fields) |field| {
        if (field.value == 0)
            return @enumFromInt(0);
    }

    return error.InvalidEnumValue;
}

pub fn decodeScalar(comptime T: type, data: []const u8, offset: u32) T {
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
        .@"struct" => |info| {
            const kind: Kind = @field(T, "kind");
            const bit_flags = switch (kind) {
                .BitFlags => |bit_flags| bit_flags,
                else => @compileError("expected bit flags"),
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
        },
        else => @compileError("expected scalar value"),
    };
}

pub fn defaultScalarValue(comptime T: type) T {
    return switch (@typeInfo(T)) {
        .int => 0,
        .float => 0.0,
        .bool => false,
        .@"struct" => .{},
        else => @compileError("expected scalar value"),
    };
}

fn getSize(comptime T: type) comptime_int {
    switch (@typeInfo(T)) {
        .int, .float, .bool => return @sizeOf(T),
        .array => |info| return info.len * getSize(info.child),
        // .pointer => return @sizeOf(u32),
        .@"struct" => |info| {
            if (info.layout != .@"packed")
                @compileError("expected packed layout");

            return @sizeOf(T);
        },

        else => @compileError("unexpected type"),
    }
}

fn getAlignment(comptime T: type) comptime_int {
    switch (@typeInfo(T)) {
        .int, .float, .bool => return @sizeOf(T),
        .array => |info| return getAlignment(info.child),
        .@"struct" => |info| {
            if (info.layout != .@"packed")
                @compileError("expected packed layout");

            var alignment = 0;
            inline for (info.fields) |field|
                alignment = @max(alignment, getAlignment(field.type));

            return alignment;
        },

        else => @compileError("unexpected type"),
    }
}

// pub fn ScalarRef(comptime T: type) type {
//     return switch (@typeInfo(T)) {
//         .int, .float => *const [@sizeOf(T)]u8,
//         .bool => *const [1]u8,
//         else => @compileError("expected scalar type"),
//     };
// }

// pub fn EnumRef(comptime T: type) type {
//     return switch (@typeInfo(T)) {
//         .@"enum" => |info| ScalarRef(info.tag_type),
//         else => @compileError("expected enum type"),
//     };
// }

// pub fn StructRef(comptime T: type) type {
//     return *align(getAlignment(T)) const u8;
// }

// pub const StringRef = ScalarRef(u32);
// pub const TableRef = ScalarRef(u32);

// pub fn decode(comptime T: type, data: []const u8, offset: u32) T {
//     switch (@typeInfo(T)) {}
// }

pub fn decodeVector(comptime T: type, data: []const u8, offset: u32) Vector(T) {
    const vec_start_offset = decodeScalar(u32, data, offset);
    const vec_offset = offset + vec_start_offset;
    const vec_len = decodeScalar(u32, data, vec_offset);
    return Vector(T){ .offset = vec_offset, .len = vec_len };
}

pub inline fn decodeString(data: []const u8, offset: u32) String {
    const str_offset = offset + decodeScalar(u32, data, offset);
    const str_len = decodeScalar(u32, data, str_offset);
    return data[str_offset + @sizeOf(u32) ..][0..str_len :0];
}

pub inline fn decodeTable(comptime T: type, data: []const u8, offset: u32) T {
    // T is a packed struct with one field `offset: u32`
    const table_offset = offset + decodeScalar(u32, data, offset);
    return T{ .offset = table_offset };
}

pub inline fn getVTableOffset(data: []const u8, table_offset: u32) u32 {
    const vtable_soffset = decodeScalar(i32, data, table_offset);
    const vtable_uoffset = @as(i32, @intCast(table_offset)) - vtable_soffset;
    return @intCast(vtable_uoffset);
}

pub inline fn getFieldOffset(data: []const u8, table_offset: u32, comptime field_index: u16) ?u32 {
    const vtable_offset = getVTableOffset(data, table_offset);
    const vtable_size = decodeScalar(u16, data, vtable_offset);
    // const table_size = decodeScalar(u16, data, vtable_offset + @sizeOf(u16));

    const vtable_entry_offset_bytes = (2 + field_index) * @sizeOf(u16);
    if (vtable_entry_offset_bytes + @sizeOf(u16) <= vtable_size) {
        const vtable_entry = decodeScalar(u16, data, vtable_offset + vtable_entry_offset_bytes);
        if (vtable_entry > 0) {
            return table_offset + vtable_entry;
        }
    }

    return null;
}
