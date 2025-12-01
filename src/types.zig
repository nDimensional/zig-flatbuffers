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

    pub fn getSize(self: Integer) u32 {
        return switch (self) {
            .u8, .i8 => 1,
            .u16, .i16 => 2,
            .u32, .i32 => 4,
            .u64, .i64 => 8,
        };
    }
};

pub const Float = enum {
    f32,
    f64,

    pub fn getSize(self: Float) u32 {
        return switch (self) {
            .f32 => 4,
            .f64 => 8,
        };
    }
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

        pub fn getSize(self: Element, schema: *const Schema) !u32 {
            return switch (self) {
                .bool => @sizeOf(u8),
                .int => |int_t| int_t.getSize(),
                .float => |float_t| float_t.getSize(),
                .@"enum" => |enum_ref| {
                    const enum_t = try schema.getEnum(enum_ref);
                    return enum_t.backing_integer.getSize();
                },
                .@"struct" => |struct_ref| {
                    const struct_t = try schema.getStruct(struct_ref);
                    return try struct_t.getSize(schema);
                },
                .bit_flags => |bit_flags_ref| {
                    const bit_flags_t = try schema.getBitFlags(bit_flags_ref);
                    return bit_flags_t.backing_integer.getSize();
                },
                .table => @sizeOf(u32),
                .string => @sizeOf(u32),
            };
        }

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
        };

        pub const Type = union(enum) {
            bool,
            int: Integer,
            float: Float,
            array: *const Struct.Field.Array,
            @"struct": StructRef,

            pub fn getSize(self: Type, schema: *const Schema) error{InvalidRef}!u32 {
                return switch (self) {
                    .bool => 1,
                    .int => |int_t| int_t.getSize(),
                    .float => |float_t| float_t.getSize(),
                    .array => |array_t| array_t.len * try array_t.element.getSize(schema),
                    .@"struct" => |struct_ref| {
                        const struct_t = try schema.getStruct(struct_ref);
                        return try struct_t.getSize(schema);
                    },
                };
            }

            pub fn format(self: Type, writer: *std.io.Writer) !void {
                switch (self) {
                    .bool => try writer.writeAll("bool"),
                    .int => |int| try writer.writeAll(@tagName(int)),
                    .float => |float| try writer.writeAll(@tagName(float)),
                    .array => |array| try writer.print("[{f}:{d}]", .{ array.element, array.len }),
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

    pub fn getSize(self: Struct, schema: *const Schema) error{InvalidRef}!u32 {
        var size: u32 = 0;
        for (self.fields) |field|
            size += try field.type.getSize(schema);
        return size;
    }

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

    pub fn format(self: Schema, writer: *std.io.Writer) !void {
        std.zon.stringify.serializeMaxDepth(self, .{
            .emit_default_optional_fields = false,
        }, writer, 16) catch return error.WriteFailed;
    }

    pub fn getEnum(self: *const Schema, enum_ref: EnumRef) !*const Enum {
        for (self.enums) |*enum_t|
            if (std.mem.eql(u8, enum_t.name, enum_ref.name))
                return enum_t;
        return error.InvalidRef;
    }

    pub fn getStruct(self: *const Schema, struct_ref: StructRef) !*const Struct {
        for (self.structs) |*struct_t|
            if (std.mem.eql(u8, struct_t.name, struct_ref.name))
                return struct_t;
        return error.InvalidRef;
    }

    pub fn getTable(self: *const Schema, table_ref: TableRef) !*const Table {
        for (self.tables) |*table_t|
            if (std.mem.eql(u8, table_t.name, table_ref.name))
                return table_t;
        return error.InvalidRef;
    }

    pub fn getUnion(self: *const Schema, union_ref: UnionRef) !*const Union {
        for (self.unions) |*union_t|
            if (std.mem.eql(u8, union_t.name, union_ref.name))
                return union_t;
        return error.InvalidRef;
    }

    pub fn getBitFlags(self: Schema, bit_flags_ref: BitFlagsRef) !*const BitFlags {
        for (self.bit_flags) |*bit_flags_t|
            if (std.mem.eql(u8, bit_flags_t.name, bit_flags_ref.name))
                return bit_flags_t;
        return error.InvalidRef;
    }

    pub fn getStructSize(self: *const Schema, struct_t: *const Struct) !u32 {
        var size: u32 = 0;
        for (struct_t.fields) |field| {
            const field_alignment = try self.getStructFieldTypeAlignment(field.type);
            size = std.mem.alignForward(u32, size, field_alignment);
            size += try self.getStructFieldTypeSize(field.type);
        }

        const struct_alignment = try self.getStructAlignment(struct_t);
        return std.mem.alignForward(u32, size, struct_alignment);
    }

    fn getStructFieldTypeSize(self: *const Schema, field_type: Struct.Field.Type) !u32 {
        return switch (field_type) {
            .bool => 1,
            .int => |int| int.getSize(),
            .float => |float| float.getSize(),
            .array => |array| {
                const array_element_size = try self.getStructFieldTypeSize(array.element);
                return array.len * array_element_size;
            },
            .@"struct" => |struct_ref| {
                const struct_t = try self.getStruct(struct_ref);
                return try self.getStructSize(struct_t);
            },
        };
    }

    pub fn getStructAlignment(self: *const Schema, struct_t: *const Struct) !u32 {
        var max_alignment: u32 = 0;
        for (struct_t.fields) |field| {
            const field_alignment = try self.getStructFieldTypeAlignment(field);
            max_alignment = @max(max_alignment, field_alignment);
        }

        return max_alignment;
    }

    fn getStructFieldTypeAlignment(self: *const Schema, field_type: Struct.Field.Type) !u32 {
        return switch (field_type) {
            .bool => 1,
            .int => |int| int.getSize(),
            .float => |float| float.getSize(),
            .array => |array| try self.getStructFieldTypeAlignment(array.element),
            .@"struct" => |struct_ref| {
                const struct_t = try self.getStruct(struct_ref);
                return try self.getStructAlignment(struct_t);
            },
        };
    }
};

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
