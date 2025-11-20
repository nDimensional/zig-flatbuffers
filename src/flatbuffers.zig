const std = @import("std");

const static = @import("static.zig");

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

pub const Type = union(enum) {
    @"enum": static.Enum,
    @"union": static.Union,
    @"struct": static.Struct,
    bit_flags: static.BitFlags,
    table: static.Table,
};

pub const Kind = union(enum) {
    // pub const BitFlagsInfo = struct {
    //     backing_integer: type,
    //     flags: []const comptime_int,
    // };

    Table,
    Struct,
    Vector,
    BitFlags,
};

pub const String = [:0]const u8;

pub fn Vector(comptime T: type) type {
    return struct {
        pub const @"#kind" = Kind.Vector;
        // pub const @"#type" = static.Vector{.}
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
                .@"enum" => item_ref.decodeEnum(T),
                .@"struct" => switch (@field(T, "#kind")) {
                    Kind.Table => decodeTable(T, item_ref),
                    Kind.Vector => @compileError("cannot nest vectors"),
                    Kind.Struct => @compileError("not implemented"),
                    Kind.BitFlags => decodeBitFlags(T, item_ref),
                },
                .pointer => decodeString(item_ref),
                .int, .float, .bool => item_ref.decodeScalar(T),
                else => @compileError("not implemented"),
            };
        }
    };
}

// fn getVectorElementType(comptime T: type) static.Vector.Element {
//     return switch (@typeInfo(T)) {
//         .bool => static.Vector.Element.bool,
//         .int => |info| static.Vector.Element{
//             .int = switch (info.bits) {
//                 8 => if (info.signed) .i8 else .u8,
//                 16 => if (info.signed) .i16 else .u16,
//                 32 => if (info.signed) .i32 else .u32,
//                 64 => if (info.signed) .i64 else .u64,
//                 else => @compileError("invalid integer type"),
//             },
//         },
//         .float => |info| static.Vector.Element{
//             .float = switch (info.bits) {
//                 32 => .f32,
//                 64 => .f64,
//             },
//         },
//         .pointer => static.Vector.Element.string,
//         .@"enum" => static.Vector.Element{
//             .@"enum" = .{ .name = @as(static.Enum, @field(T, "#type")).name },
//         },
//         .@"struct" => switch (@field(T, "#kind")) {
//             Kind.Table => static.Vector.Element{
//                 .table = .{ .name = @as(static.Table, @field(T, "#type")).name },
//             },
//             Kind.Vector => @compileError("cannot nest vectors"),
//             Kind.Struct => static.Vector.Element{
//                 .@"struct" = .{ .name = @as(static.Struct, @field(T, "#type")).name },
//             },
//             Kind.BitFlags => static.Vector.Element{
//                 .bit_flags = .{ .name = @as(static.BitFlags, @field(T, "#type")).name },
//             },
//         },
//         else => @compileError("invalid vector type"),
//     };
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
                const bit_flags: static.BitFlags = @field(T, "#type");
                return switch (bit_flags.backing_integer) {
                    .u8 => 1,
                    .u16 => 2,
                    .u32 => 4,
                    .u64 => 8,
                    else => @compileError("invalid bit flags backing integer"),
                };
            },
        },

        else => @compileError("unexpected type"),
    };
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

pub fn getStructAlignment(comptime T: type) u32 {
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

pub fn decodeStructField(comptime T: type, comptime id: u16, table_ref: Ref, comptime default: T) T {
    const field_ref = getFieldRef(table_ref, id) orelse
        return default;
    _ = field_ref;
    @panic("not implemented");
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
    const info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError("expected bit flags struct"),
    };

    const bit_flags: static.BitFlags = comptime @field(T, "#type");

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

fn getFieldRef(table_ref: Ref, comptime id: u16) ?Ref {
    const vtable_ref = table_ref.soffset();
    const vtable_size = vtable_ref.decodeScalar(u16);
    // const object_size = vtable_ref.add(2).decodeScalar(u16);

    const vtable_entry_index = 2 + id;
    const vtable_entry_start = vtable_entry_index * @sizeOf(u16);
    const vtable_entry_end = vtable_entry_start + @sizeOf(u16);
    if (vtable_entry_end > vtable_size)
        return null;

    const vtable_entry = vtable_ref.add(vtable_entry_start).decodeScalar(u16);
    if (vtable_entry == 0)
        return null;

    return table_ref.add(vtable_entry);
}
