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

    pub fn write(self: Enum, writer: *std.io.Writer) !void {
        if (self.documentation) |documentation|
            for (documentation) |line|
                try writer.print("/// {s}\n", .{line});

        try writer.print(
            \\pub const @"{s}" = enum({s}) {{
            \\    pub const @"#type" = {f};
            \\
            \\
        , .{ pop(self.name), @tagName(self.backing_integer), self });

        for (self.values) |value| {
            if (value.documentation) |documentation|
                for (documentation) |line|
                    try writer.print("    /// {s}\n", .{line});
            try writer.print(
                \\    @"{s}" = {d},
                \\
            , .{ value.name, value.value });
        }

        try writer.writeAll("};\n\n");
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

    pub fn write(self: Union, writer: *std.io.Writer) !void {
        if (self.documentation) |documentation|
            for (documentation) |line|
                try writer.print("/// {s}\n", .{line});

        try writer.print(
            \\pub const @"{s}" = union(enum(u8)) {{
            \\    pub const @"#type" = {f};
            \\
            \\
        , .{ pop(self.name), self });

        try writer.writeAll(
            \\    NONE: void = 0,
            \\
        );
        for (self.options, 1..) |option, value| {
            if (option.documentation) |documentation|
                for (documentation) |line|
                    try writer.print("    /// {s}\n", .{line});
            try writer.print(
                \\    @"{s}": {f} = {d},
                \\
            , .{ pop(option.table.name), esc(option.table.name), value });
        }

        try writer.writeAll("};\n\n");
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

    pub fn write(self: Table, writer: *std.io.Writer) !void {
        if (self.documentation) |documentation|
            for (documentation) |line|
                try writer.print("/// {s}\n", .{line});

        try writer.print(
            \\pub const @"{s}" = struct {{
            \\    pub const @"#kind" = flatbuffers.Kind.Table;
            \\    pub const @"#type" = {f};
            \\
            \\    @"#ref": flatbuffers.Ref,
            \\
            \\
        , .{ pop(self.name), self });

        var field_id: u16 = 0;
        for (self.fields) |field| {
            if (field.deprecated) {
                field_id += 1;
                if (field.type == .@"union")
                    field_id += 1;
                continue;
            }

            if (field.documentation) |documentation|
                for (documentation) |line|
                    try writer.print("    /// {s}\n", .{line});

            try writer.print(
                \\    pub fn @"{s}"(@"#self": @"{s}")
            , .{ field.name, pop(self.name) });

            switch (field.type) {
                .bool => try writer.print(
                    \\ bool {{
                    \\        return flatbuffers.decodeScalarField(bool, {d}, @"#self".@"#ref", {});
                    \\    }}
                , .{ field_id, field.default_integer != 0 }),
                .int => |int| try writer.print(
                    \\ {s} {{
                    \\        return flatbuffers.decodeScalarField({s}, {d}, @"#self".@"#ref", {d});
                    \\    }}
                , .{ @tagName(int), @tagName(int), field_id, field.default_integer }),
                .float => |float| try writer.print(
                    \\ {s} {{
                    \\        return flatbuffers.decodeScalarField({s}, {d}, @"#self".@"#ref", {d});
                    \\    }}
                , .{ @tagName(float), @tagName(float), field_id, field.default_real }),
                .@"enum" => |enum_t| try writer.print(
                    \\ {f} {{
                    \\        return flatbuffers.decodeEnumField({f}, {d}, @"#self".@"#ref", @enumFromInt({d}));
                    \\    }}
                , .{ esc(enum_t.name), esc(enum_t.name), field_id, field.default_integer }),
                .bit_flags => |bit_flags| {
                    // TODO: default bit flag values
                    try writer.print(
                        \\ {f} {{
                        \\        return flatbuffers.decodeBitFlagsField({f}, {d}, @"#self".@"#ref", {s}{{}});
                        \\    }}
                    , .{ esc(bit_flags.name), esc(bit_flags.name), field_id, bit_flags.name });
                },
                .string => if (field.required) {
                    try writer.print(
                        \\ flatbuffers.String {{
                        \\        return flatbuffers.decodeStringField({d}, @"#self".@"#ref") orelse
                        \\            @panic("missing {s}.{s} field");
                        \\    }}
                    , .{ field_id, self.name, field.name });
                } else {
                    try writer.print(
                        \\ ?flatbuffers.String {{
                        \\        return flatbuffers.decodeStringField({d}, @"#self".@"#ref");
                        \\    }}
                    , .{field_id});
                },
                .vector => |vector| if (field.required) {
                    try writer.print(
                        \\ flatbuffers.Vector({f}) {{
                        \\        return flatbuffers.decodeVectorField({f}, {d}, @"#self".@"#ref") orelse
                        \\            @panic("missing {s}.{s} field");
                        \\    }}
                    , .{ vector.element, vector.element, field_id, self.name, field.name });
                } else {
                    try writer.print(
                        \\ ?flatbuffers.Vector({f}) {{
                        \\        return flatbuffers.decodeVectorField({f}, {d}, @"#self".@"#ref");
                        \\    }}
                    , .{ vector.element, vector.element, field_id });
                },
                .table => |table| if (field.required) {
                    try writer.print(
                        \\ {f} {{
                        \\        return flatbuffers.decodeTableField({f}, {d}, @"#self".@"#ref") orelse
                        \\            @panic("missing {s}.{s} field");
                        \\    }}
                    , .{ esc(table.name), esc(table.name), field_id, self.name, field.name });
                } else {
                    try writer.print(
                        \\ ?{f} {{
                        \\        return flatbuffers.decodeTableField({f}, {d}, @"#self".@"#ref");
                        \\    }}
                    , .{ esc(table.name), esc(table.name), field_id });
                },
                .@"struct" => |struct_t| {
                    _ = struct_t;
                    return error.NotImplemented;
                },
                .@"union" => |union_t| {
                    try writer.print(
                        \\ {f} {{
                        \\        return flatbuffers.decodeUnionField({f}, {d}, {d}, @"#self".@"#ref");
                        \\    }}
                    , .{ esc(union_t.name), esc(union_t.name), field_id, field_id + 1 });

                    field_id += 1;
                },
            }

            field_id += 1;

            _ = try writer.splatByte('\n', 2);
        }

        try writer.writeAll("};\n\n");
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

    pub fn write(self: Struct, writer: *std.io.Writer) !void {
        if (self.documentation) |documentation|
            for (documentation) |line|
                try writer.print("/// {s}\n", .{line});

        try writer.print(
            \\pub const @"{s}" = struct {{
            \\    pub const @"#kind" = flatbuffers.Kind.Struct;
            \\    pub const @"#type" = {f};
            \\
        , .{ pop(self.name), self });

        for (self.fields) |field| {
            if (field.documentation) |documentation|
                for (documentation) |line|
                    try writer.print("    /// {s}\n", .{line});
            try writer.print(
                \\    @"{s}": {f},
                \\
            , .{ field.name, field.type });
        }

        try writer.writeAll("};\n\n");
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

    pub fn write(self: BitFlags, writer: *std.io.Writer) !void {
        if (self.documentation) |documentation|
            for (documentation) |line|
                try writer.print("/// {s}\n", .{line});

        var flags_buffer: [256]u8 = undefined;
        var flags_writer = std.io.Writer.fixed(&flags_buffer);
        for (self.fields, 0..) |field, i| {
            if (i > 0)
                try flags_writer.writeAll(", ");

            try flags_writer.print("{d}", .{field.value});
        }

        const flags = flags_writer.buffered();

        try writer.print(
            \\pub const {s} = packed struct {{
            \\    pub const @"#kind" = flatbuffers.Kind.BitFlags;
            \\
            \\
        , .{ pop(self.name), @tagName(self.backing_integer), flags });

        for (self.fields) |field| {
            if (field.documentation) |documentation|
                for (documentation) |line|
                    try writer.print("    /// {s}\n", .{line});
            try writer.print(
                \\    @"{s}": bool = false,
                \\
            , .{field.name});
        }

        try writer.writeAll("};\n\n");
    }
};

const NamespacePrefixMap = struct {
    allocator: std.mem.Allocator,
    map: std.StringArrayHashMapUnmanaged(usize) = std.StringArrayHashMapUnmanaged(usize).empty,

    pub fn init(allocator: std.mem.Allocator) NamespacePrefixMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NamespacePrefixMap) void {
        self.map.deinit(self.allocator);
    }

    pub fn add(
        self: *NamespacePrefixMap,
        name: []const u8,
    ) !void {
        var start: usize = 0;
        while (std.mem.indexOfScalarPos(u8, name, start, '.')) |i| : (start = i + 1) {
            const prefix = name[0 .. i + 1];
            const level = std.mem.count(u8, prefix, ".");
            try self.map.put(self.allocator, prefix, level);
        }
    }

    pub fn sort(self: *NamespacePrefixMap) void {
        self.map.sort(struct {
            keys: [][]const u8,

            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                return std.mem.lessThan(u8, ctx.keys[a_index], ctx.keys[b_index]);
            }
        }{ .keys = self.map.keys() });
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

    pub fn write(self: Schema, allocator: std.mem.Allocator, writer: *std.io.Writer) !void {
        try writer.writeAll(
            \\const std = @import("std");
            \\
            \\const flatbuffers = @import("flatbuffers.zig");
            \\
            \\
        );

        var namespaces = NamespacePrefixMap.init(allocator);
        defer namespaces.deinit();

        for (self.enums) |t| try namespaces.add(t.name);
        for (self.bit_flags) |t| try namespaces.add(t.name);
        for (self.structs) |t| try namespaces.add(t.name);
        for (self.unions) |t| try namespaces.add(t.name);
        for (self.tables) |t| try namespaces.add(t.name);

        namespaces.sort();

        const count = namespaces.map.count();
        const keys = namespaces.map.keys();
        const values = namespaces.map.values();
        for (keys, values, 0..) |namespace, level, i| {
            var name_start: usize = 0;
            if (std.mem.lastIndexOfScalar(u8, namespace[0 .. namespace.len - 1], '.')) |last_index|
                name_start = last_index + 1;
            const name = namespace[name_start .. namespace.len - 1];
            try writer.print("pub const {s} = struct ", .{name});
            try writer.writeAll("{\n");

            try self.writeNamespace(namespace, writer);

            var closing_count = level;
            if (i + 1 < count)
                closing_count -= @min(level, values[i + 1]);

            for (0..closing_count) |_|
                try writer.writeAll("};\n");
        }

        // if (self.root.file_ident()) |file_identifier|
        //     try writer.print("pub const file_identifier = \"{s}\";\n", .{file_identifier});

        // if (self.root.file_ext()) |file_extension|
        //     try writer.print("pub const file_extension = \"{s}\";\n", .{file_extension});

        // for (self.enums) |t| try t.write(writer);
        // for (self.bit_flags) |t| try t.write(writer);
        // for (self.structs) |t| try t.write(writer);
        // for (self.unions) |t| try t.write(writer);
        // for (self.tables) |t| try t.write(writer);
    }

    fn writeNamespace(self: Schema, namespace: []const u8, writer: *std.io.Writer) !void {
        for (self.enums) |t|
            if (isInNamespace(namespace, t.name))
                try t.write(writer);

        for (self.bit_flags) |t|
            if (isInNamespace(namespace, t.name))
                try t.write(writer);

        for (self.structs) |t|
            if (isInNamespace(namespace, t.name))
                try t.write(writer);

        for (self.unions) |t|
            if (isInNamespace(namespace, t.name))
                try t.write(writer);

        for (self.tables) |t|
            if (isInNamespace(namespace, t.name))
                try t.write(writer);
    }
};

fn isInNamespace(namespace: []const u8, name: []const u8) bool {
    const end = std.mem.lastIndexOfScalar(u8, name, '.') orelse
        return false;
    return std.mem.eql(u8, namespace, name[0 .. end + 1]);
}

pub inline fn pop(name: []const u8) []const u8 {
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
