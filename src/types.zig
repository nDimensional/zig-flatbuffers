const std = @import("std");

pub const Integer = enum {
    u8,
    i8,
    u16,
    i16,
    u32,
    i32,
    u64,
    i64,
};

pub const Float = enum {
    f32,
    f64,
};

pub const EnumRef = struct { name: []const u8 };
pub const TableRef = struct { name: []const u8 };
pub const UnionRef = struct { name: []const u8 };
pub const StructRef = struct { name: []const u8 };
pub const BitFlagsRef = struct { name: []const u8 };

pub const Enum = struct {
    pub const Value = struct {
        name: []const u8,
        value: i64,
        documentation: ?[]const []const u8 = null,
    };

    name: []const u8,
    backing_integer: Integer,
    values: []const Enum.Value,
    documentation: ?[]const []const u8 = null,

    pub fn format(self: Enum, writer: *std.io.Writer) !void {
        try std.zon.stringify.serialize(self, .{
            .emit_default_optional_fields = false,
        }, writer);
    }
};

pub const Union = struct {
    pub const Option = struct {
        documentation: ?[]const []const u8 = null,
        table: TableRef,
    };

    name: []const u8,
    options: []const Option,
    documentation: ?[]const []const u8 = null,

    pub fn format(self: Union, writer: *std.io.Writer) !void {
        try std.zon.stringify.serialize(self, .{
            .emit_default_optional_fields = false,
        }, writer);
    }
};

pub const Table = struct {
    pub const Field = struct {
        pub const Type = union(enum) {
            bool,
            float: Float,
            int: Integer,
            @"enum": EnumRef,
            @"struct": StructRef,
            bit_flags: BitFlagsRef,
            table: TableRef,
            @"union": UnionRef,
            vector: Vector,
            string,
        };

        name: []const u8,
        type: Table.Field.Type,
        required: bool = false,
        deprecated: bool = false,
        default_integer: i64 = 0,
        default_real: f64 = 0,
        documentation: ?[]const []const u8 = null,
    };

    name: []const u8,
    fields: []const Table.Field,
    documentation: ?[]const []const u8 = null,

    pub fn format(self: Table, writer: *std.io.Writer) !void {
        try std.zon.stringify.serialize(self, .{
            .emit_default_optional_fields = false,
        }, writer);
    }
};

pub const Vector = struct {
    pub const Element = union(enum) {
        bool,
        int: Integer,
        float: Float,
        @"enum": EnumRef,
        @"struct": StructRef,
        bit_flags: BitFlagsRef,
        table: TableRef,
        string,

        pub fn format(self: Element, writer: *std.io.Writer) !void {
            switch (self) {
                .bool => try writer.writeAll("bool"),
                .int => |int| try writer.writeAll(@tagName(int)),
                .float => |float| try writer.writeAll(@tagName(float)),
                .@"enum" => |t| try esc(t.name).format(writer),
                .@"struct" => |t| try esc(t.name).format(writer),
                .bit_flags => |t| try esc(t.name).format(writer),
                .table => |t| try esc(t.name).format(writer),
                .string => try writer.writeAll("flatbuffers.String"),
            }
        }
    };

    element: Vector.Element,

    pub fn format(self: Vector, writer: *std.io.Writer) !void {
        try writer.print("Vector({f})", .{self.element});
    }
};

pub const Struct = struct {
    pub const Field = struct {
        pub const Array = struct {
            len: u32,
            element: Struct.Field.Type,

            pub inline fn format(self: Array, writer: *std.io.Writer) !void {
                try writer.print("[{f}:{d}]", .{ self.element, self.len });
            }
        };

        pub const Type = union(enum) {
            bool,
            int: Integer,
            float: Float,
            array: *const Struct.Field.Array,
            @"struct": StructRef,

            pub fn format(self: Type, writer: *std.io.Writer) !void {
                switch (self) {
                    .bool => try writer.writeAll("bool"),
                    .int => |int| try writer.writeAll(@tagName(int)),
                    .float => |float| try writer.writeAll(@tagName(float)),
                    .array => |array| try array.format(writer),
                    .@"struct" => |t| try esc(t.name).format(writer),
                }
            }
        };

        name: []const u8,
        type: Struct.Field.Type,
        documentation: ?[]const []const u8 = null,
    };

    name: []const u8,
    fields: []const Struct.Field,
    documentation: ?[]const []const u8 = null,

    pub fn format(self: Struct, writer: *std.io.Writer) !void {
        std.zon.stringify.serializeMaxDepth(self, .{
            .emit_default_optional_fields = false,
        }, writer, 16) catch {
            return error.WriteFailed;
        };
    }
};

pub const BitFlags = struct {
    pub const Field = struct {
        name: []const u8,
        value: u64,
        documentation: ?[]const []const u8 = null,
    };

    name: []const u8,
    backing_integer: Integer,
    fields: []const BitFlags.Field,
    documentation: ?[]const []const u8 = null,

    pub inline fn format(self: BitFlags, writer: *std.io.Writer) !void {
        try std.zon.stringify.serialize(self, .{
            .emit_default_optional_fields = false,
        }, writer);
    }
};

pub const Schema = struct {
    file_ident: ?[]const u8 = null,
    file_ext: ?[]const u8 = null,

    tables: []const Table,
    enums: []const Enum,
    unions: []const Union,
    structs: []const Struct,
    bit_flags: []const BitFlags,

    root_table: ?TableRef = null,
};

inline fn pop(name: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, name, '.')) |end| {
        return name[end + 1 ..];
    } else {
        return name;
    }
}

const Escape = struct {
    name: []const u8,

    pub fn format(self: Escape, writer: *std.io.Writer) !void {
        var iter = std.mem.splitScalar(u8, self.name, '.');
        var i: usize = 0;
        while (iter.next()) |term| : (i += 1) {
            if (i > 0)
                try writer.writeByte('.');
            try writer.print("@\"{s}\"", .{term});
        }
    }
};

inline fn esc(name: []const u8) Escape {
    return .{ .name = name };
}
