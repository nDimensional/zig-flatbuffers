const std = @import("std");

const flatbuffers = @import("flatbuffers");
const types = flatbuffers.types;

const reflection = @import("reflection.zig").reflection;

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

pub fn writeEnum(self: types.Enum, index: usize, writer: *std.io.Writer) !void {
    if (self.documentation) |documentation|
        for (documentation) |line|
            try writer.print("///{s}\n", .{line});

    try writer.print(
        \\pub const @"{s}" = enum({s}) {{
        \\    pub const @"#kind" = flatbuffers.Kind.Enum;
        \\    pub const @"#root" = &@"#schema";
        \\    pub const @"#type" = &@"#schema".enums[{d}];
        \\
        \\
    , .{ pop(self.name), @tagName(self.backing_integer), index });

    for (self.values) |value| {
        if (value.documentation) |documentation|
            for (documentation) |line|
                try writer.print("    ///{s}\n", .{line});
        try writer.print(
            \\    @"{s}" = {d},
            \\
        , .{ value.name, value.value });
    }

    try writer.writeAll("};\n\n");
}

pub fn writeUnion(self: types.Union, index: usize, writer: *std.io.Writer) !void {
    if (self.documentation) |documentation|
        for (documentation) |line|
            try writer.print("///{s}\n", .{line});

    try writer.print(
        \\pub const @"{s}" = union(enum(u8)) {{
        \\    pub const @"#kind" = flatbuffers.Kind.Union;
        \\    pub const @"#root" = &@"#schema";
        \\    pub const @"#type" = &@"#schema".unions[{d}];
        \\
        \\
    , .{ pop(self.name), index });

    try writer.writeAll(
        \\    NONE: void = 0,
        \\
    );
    for (self.options, 1..) |option, value| {
        if (option.documentation) |documentation|
            for (documentation) |line|
                try writer.print("    ///{s}\n", .{line});
        try writer.print(
            \\    @"{s}": {f} = {d},
            \\
        , .{ pop(option.table.name), esc(option.table.name), value });
    }

    try writer.writeAll("};\n\n");
}

const TableConstructor = struct {
    table: types.Table,

    pub fn format(self: TableConstructor, writer: *std.io.Writer) !void {
        try writer.writeAll("struct {\n");

        for (self.table.fields) |field| {
            if (field.deprecated)
                continue;

            try writer.print("{f}: ", .{esc(field.name)});
            switch (field.type) {
                .bool => try writer.print("bool = {}", .{field.default_integer != 0}),
                .float => |float| try writer.print("{s} = {d}", .{ @tagName(float), field.default_real }),
                .int => |int| try writer.print("{s} = {d}", .{ @tagName(int), field.default_integer }),
                .@"enum" => |enum_ref| try writer.print("{f} = @enumFromInt({d})", .{ esc(enum_ref.name), field.default_integer }),
                .@"struct" => |struct_ref| {
                    if (field.required)
                        try writer.writeByte('?');
                    try esc(struct_ref.name).format(writer);
                },
                .bit_flags => |bit_flags_ref| {
                    try writer.print("{f} = .{{}}", .{esc(bit_flags_ref.name)});
                },
                .table => |table_ref| {
                    if (field.required)
                        try writer.writeByte('?');
                    try esc(table_ref.name).format(writer);
                },
                .@"union" => |union_ref| {
                    try writer.print("{f} = .NONE", .{esc(union_ref.name)});
                },
                .vector => |vector| {
                    if (field.required)
                        try writer.writeByte('?');
                    try writer.writeAll("[]const ");
                    switch (vector.element) {
                        .bool => try writer.writeAll("bool"),
                        .int => |int| try writer.writeAll(@tagName(int)),
                        .float => |float| try writer.writeAll(@tagName(float)),
                        .@"enum" => |enum_ref| try esc(enum_ref.name).format(writer),
                        .@"struct" => |struct_ref| try esc(struct_ref.name).format(writer),
                        .bit_flags => |bit_flags_ref| try esc(bit_flags_ref.name).format(writer),
                        .table => |table_ref| try esc(table_ref.name).format(writer),
                        .string => try writer.writeAll("[]const u8"),
                    }
                },
                .string => {
                    if (field.required)
                        try writer.writeByte('?');
                    try writer.writeAll("[]const u8");
                },
            }
            try writer.writeAll(", ");
        }

        try writer.writeAll("}");
    }
};

pub fn writeTable(self: types.Table, index: usize, writer: *std.io.Writer) !void {
    if (self.documentation) |documentation|
        for (documentation) |line|
            try writer.print("///{s}\n", .{line});

    try writer.print(
        \\pub const @"{s}" = struct {{
        \\    pub const @"#kind" = flatbuffers.Kind.Table;
        \\    pub const @"#root" = &@"#schema";
        \\    pub const @"#type" = &@"#schema".tables[{d}];
        \\    pub const @"#constructor" = {f};
        \\
        \\    @"#ref": flatbuffers.Ref,
        \\
        \\
    , .{ pop(self.name), index, TableConstructor{ .table = self } });

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
                try writer.print("    ///{s}\n", .{line});

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
            .bit_flags => |bit_flags| try writer.print(
                \\ {f} {{
                \\        return flatbuffers.decodeBitFlagsField({f}, {d}, @"#self".@"#ref", {s}{{}});
                \\    }}
            , .{ esc(bit_flags.name), esc(bit_flags.name), field_id, bit_flags.name }),
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
            .table => |table_ref| if (field.required) {
                try writer.print(
                    \\ {f} {{
                    \\        return flatbuffers.decodeTableField({f}, {d}, @"#self".@"#ref") orelse
                    \\            @panic("missing {s}.{s} field");
                    \\    }}
                , .{ esc(table_ref.name), esc(table_ref.name), field_id, self.name, field.name });
            } else {
                try writer.print(
                    \\ ?{f} {{
                    \\        return flatbuffers.decodeTableField({f}, {d}, @"#self".@"#ref");
                    \\    }}
                , .{ esc(table_ref.name), esc(table_ref.name), field_id });
            },
            .@"struct" => |struct_ref| if (field.required) {
                try writer.print(
                    \\ {f} {{
                    \\        return flatbuffers.decodeStructField({f}, {d}, @"#self".@"#ref") orelse
                    \\            @panic("missing {s}.{s} field");
                    \\    }}
                , .{ esc(struct_ref.name), esc(struct_ref.name), field_id, self.name, field.name });
            } else {
                try writer.print(
                    \\ ?{f} {{
                    \\        return flatbuffers.decodeStructField({f}, {d}, @"#self".@"#ref");
                    \\    }}
                , .{ esc(struct_ref.name), esc(struct_ref.name), field_id });
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

pub fn writeStruct(self: types.Struct, index: usize, writer: *std.io.Writer) !void {
    if (self.documentation) |documentation|
        for (documentation) |line|
            try writer.print("///{s}\n", .{line});

    try writer.print(
        \\pub const @"{s}" = struct {{
        \\    pub const @"#kind" = flatbuffers.Kind.Struct;
        \\    pub const @"#root" = &@"#schema";
        \\    pub const @"#type" = &@"#schema".structs[{d}];
        \\
    , .{ pop(self.name), index });

    for (self.fields) |field| {
        if (field.documentation) |documentation|
            for (documentation) |line|
                try writer.print("    ///{s}\n", .{line});
        try writer.print(
            \\    @"{s}": {f},
            \\
        , .{ field.name, field.type });
    }

    try writer.writeAll("};\n\n");
}

pub fn writeBitFlags(self: types.BitFlags, index: usize, writer: *std.io.Writer) !void {
    if (self.documentation) |documentation|
        for (documentation) |line|
            try writer.print("///{s}\n", .{line});

    var flags_buffer: [256]u8 = undefined;
    var flags_writer = std.io.Writer.fixed(&flags_buffer);
    for (self.fields, 0..) |field, i| {
        if (i > 0)
            try flags_writer.writeAll(", ");

        try flags_writer.print("{d}", .{field.value});
    }

    try writer.print(
        \\pub const {s} = packed struct {{
        \\    pub const @"#kind" = flatbuffers.Kind.BitFlags;
        \\    pub const @"#root" = &@"#schema";
        \\    pub const @"#type" = &@"#schema".bit_flags[{d}];
        \\
        \\
    , .{ pop(self.name), index });

    for (self.fields) |field| {
        if (field.documentation) |documentation|
            for (documentation) |line|
                try writer.print("    ///{s}\n", .{line});
        try writer.print(
            \\    @"{s}": bool = false,
            \\
        , .{field.name});
    }

    try writer.writeAll("};\n\n");
}

const NamespacePrefixMap = struct {
    allocator: std.mem.Allocator,
    map: std.StringArrayHashMapUnmanaged(usize) = std.StringArrayHashMapUnmanaged(usize).empty,

    pub fn init(allocator: std.mem.Allocator) NamespacePrefixMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NamespacePrefixMap) void {
        self.map.deinit(self.allocator);
    }

    pub fn add(self: *NamespacePrefixMap, name: []const u8) !void {
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

pub fn writeSchema(self: types.Schema, allocator: std.mem.Allocator, ir_filename: []const u8, writer: *std.io.Writer) !void {
    try writer.print(
        \\const std = @import("std");
        \\
        \\const flatbuffers = @import("flatbuffers");
        \\
        \\const @"#schema": flatbuffers.types.Schema = @import("{s}");
        \\
        \\
    , .{ir_filename});

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

        try writeNamespace(self, namespace, writer);

        var closing_count = level;
        if (i + 1 < count)
            closing_count -= @min(level, values[i + 1]);

        for (0..closing_count) |_|
            try writer.writeAll("};\n");
    }

    try writeNamespace(self, null, writer);

    // if (self.root.file_ident()) |file_identifier|
    //     try writer.print("pub const file_identifier = \"{s}\";\n", .{file_identifier});

    // if (self.root.file_ext()) |file_extension|
    //     try writer.print("pub const file_extension = \"{s}\";\n", .{file_extension});

}

fn writeNamespace(schema: types.Schema, namespace: ?[]const u8, writer: *std.io.Writer) !void {
    for (schema.enums, 0..) |t, i|
        if (isInNamespace(namespace, t.name))
            try writeEnum(t, i, writer);

    for (schema.bit_flags, 0..) |t, i|
        if (isInNamespace(namespace, t.name))
            try writeBitFlags(t, i, writer);

    for (schema.structs, 0..) |t, i|
        if (isInNamespace(namespace, t.name))
            try writeStruct(t, i, writer);

    for (schema.unions, 0..) |t, i|
        if (isInNamespace(namespace, t.name))
            try writeUnion(t, i, writer);

    for (schema.tables, 0..) |t, i|
        if (isInNamespace(namespace, t.name))
            try writeTable(t, i, writer);
}

fn isInNamespace(namespace: ?[]const u8, name: []const u8) bool {
    if (namespace) |prefix| {
        const end = std.mem.lastIndexOfScalar(u8, name, '.') orelse
            return false;
        return std.mem.eql(u8, prefix, name[0 .. end + 1]);
    } else {
        return std.mem.indexOfScalar(u8, name, '.') == null;
    }
}

pub fn main() !void {
    var args = std.process.args();

    _ = args.next() orelse unreachable;

    const ir_path = args.next() orelse {
        std.log.err("missing schema path argument", .{});
        return;
    };

    const ir_filename = std.fs.path.basename(ir_path);
    const file_ext_index = std.mem.lastIndexOfScalar(u8, ir_filename, '.') orelse
        return error.InvalidFileExtension;
    if (!std.mem.eql(u8, ir_filename[file_ext_index..], ".zon"))
        return error.InvalidFileExtension;

    const file = try std.fs.cwd().openFile(ir_path, .{});
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

    const allocator = std.heap.c_allocator;
    const copy = try allocator.dupeZ(u8, data);
    defer allocator.free(copy);
    const schema = try std.zon.parse.fromSlice(flatbuffers.types.Schema, allocator, copy, null, .{});

    // var parser = try Parser.init(std.heap.c_allocator, @alignCast(data));
    // defer parser.deinit();

    // const result = try parser.parse(s

    var buffer: [4096]u8 = undefined;
    const output = std.fs.File.stdout();
    var output_writer = output.writer(&buffer);

    // try writeSchema(result.schema, std.heap.c_allocator, &output_writer.interface);
    try writeSchema(schema, allocator, ir_filename, &output_writer.interface);

    try output_writer.interface.flush();
}
