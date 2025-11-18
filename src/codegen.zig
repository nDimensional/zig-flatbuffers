const std = @import("std");

const flatbuffers = @import("flatbuffers.zig");
const String = flatbuffers.String;
const Vector = flatbuffers.Vector;

const reflection = @import("reflection.zig").reflection;
const decodeRoot = @import("reflection.zig").decodeRoot;

const Generator = struct {
    allocator: std.mem.Allocator,
    data: []align(8) const u8,

    root: reflection.Schema,
    enums: Vector(reflection.Enum),
    objects: Vector(reflection.Object),

    field_id_buffer: std.ArrayList(usize),
    namespace_prefix_map: std.StringArrayHashMapUnmanaged(usize),

    pub fn init(allocator: std.mem.Allocator, data: []align(8) const u8) !Generator {
        const schema = decodeRoot(data);
        const enums = schema.enums();
        const objects = schema.objects();

        return Generator{
            .allocator = allocator,
            .data = data,
            .root = schema,
            .enums = enums,
            .objects = objects,
            .field_id_buffer = std.ArrayList(usize).empty,
            .namespace_prefix_map = std.StringArrayHashMapUnmanaged(usize).empty,
        };
    }

    pub inline fn deinit(self: *Generator) void {
        self.field_id_buffer.deinit(self.allocator);
        self.namespace_prefix_map.deinit(self.allocator);
    }

    pub fn generate(self: *Generator, writer: *std.io.Writer) !void {
        try writer.writeAll(
            \\const std = @import("std");
            \\
            \\const flatbuffers = @import("flatbuffers.zig");
            \\
            \\
        );

        if (self.root.file_ident()) |file_identifier|
            try writer.print("pub const file_identifier = \"{s}\";\n", .{file_identifier});

        if (self.root.file_ext()) |file_extension|
            try writer.print("pub const file_extension = \"{s}\";\n", .{file_extension});

        try writer.writeByte('\n');

        // here we build a list of all partial namespace prefixes, e.g.
        // 0: "org"
        // 1: "org.apache"
        // 2: "org.apache.arrow"
        // 3: "org.apache.arrow.flatbuf"
        // ... which will get sorted and each written as a nested namespace struct.

        for (0..self.enums.len()) |i|
            try self.addNamespacePrefix(self.enums.at(i).name());

        for (0..self.objects.len()) |i|
            try self.addNamespacePrefix(self.objects.at(i).name());

        // sort
        const keys = self.namespace_prefix_map.keys();
        const values = self.namespace_prefix_map.values();
        self.namespace_prefix_map.sort(struct {
            keys: [][]const u8,

            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                return std.mem.lessThan(u8, ctx.keys[a_index], ctx.keys[b_index]);
            }
        }{ .keys = keys });

        const count = self.namespace_prefix_map.count();

        // now we have a list of all partial prefixes.
        for (keys, values, 0..) |prefix, level, i| {
            var name_start: usize = 0;
            if (std.mem.lastIndexOfScalar(u8, prefix[0 .. prefix.len - 1], '.')) |last_index|
                name_start = last_index + 1;
            const name = prefix[name_start .. prefix.len - 1];
            try writer.print("pub const {s} = struct ", .{name});
            try writer.writeAll("{\n");

            for (0..self.enums.len()) |j| {
                const enum_item = self.enums.at(j);
                const enum_name = enum_item.name();
                const prefix_end = std.mem.lastIndexOfScalar(u8, enum_name, '.') orelse continue;
                if (std.mem.eql(u8, prefix, enum_name[0 .. prefix_end + 1])) {
                    try self.writeEnumDeclaration(writer, enum_item, enum_name[prefix.len..]);
                }
            }

            for (0..self.objects.len()) |j| {
                const object = self.objects.at(j);
                const object_name = object.name();
                const prefix_end = std.mem.lastIndexOfScalar(u8, object_name, '.') orelse continue;
                if (std.mem.eql(u8, prefix, object_name[0 .. prefix_end + 1])) {
                    if (object.is_struct()) {
                        try self.writeStructDeclaration(writer, object, object_name[prefix.len..]);
                    } else {
                        try self.writeTableDeclaration(writer, object, object_name[prefix.len..]);
                    }
                }
            }

            var closing_count = level;
            if (i + 1 < count)
                closing_count -= @min(level, values[i + 1]);

            for (0..closing_count) |_|
                try writer.writeAll("};\n");
        }

        if (self.root.root_table()) |root_table| {
            try writer.print(
                \\
                \\pub fn decodeRoot(data: []align(8) const u8) {s} {{
                \\    const start = flatbuffers.Ref{{
                \\        .ptr = data.ptr,
                \\        .len = @truncate(data.len),
                \\        .offset = 0,
                \\    }};
                \\
                \\    return .{{ .@"#ref" = start.uoffset() }};
                \\}}
                \\
            , .{root_table.name()});

            try writer.writeAll(
                \\
                \\pub fn validateRoot(data: []align(8) const u8) !void {
                \\    if (data.len < 8)
                \\        return error.Invalid;
                \\
                \\    const root = decodeRoot(data);
                \\    if (root.offset >= data.len)
                \\        return error.Invalid;
                \\}
                \\
            );
        }

        try writer.flush();
    }

    fn addNamespacePrefix(self: *Generator, name: []const u8) !void {
        var start: usize = 0;
        while (std.mem.indexOfScalarPos(u8, name, start, '.')) |i| : (start = i + 1) {
            const prefix = name[0 .. i + 1];
            const level = std.mem.count(u8, prefix, ".");
            try self.namespace_prefix_map.put(self.allocator, prefix, level);
        }
    }

    inline fn getEnum(self: *Generator, enum_index: i32) !reflection.Enum {
        if (enum_index < 0 or enum_index >= self.enums.len())
            return error.InvalidEnumIndex;

        return self.enums.at(@intCast(enum_index));
    }

    inline fn getObject(self: *Generator, object_index: i32) !reflection.Object {
        if (object_index < 0 or object_index >= self.objects.len())
            return error.InvalidEnumIndex;

        return self.objects.at(@intCast(object_index));
    }

    fn writeEnumDeclaration(
        _: *Generator,
        writer: *std.io.Writer,
        enum_ref: reflection.Enum,
        enum_name: []const u8,
    ) !void {
        const base_type = enum_ref.underlying_type().base_type();
        const is_union = enum_ref.is_union();
        const is_bit_flag = hasBitFlags(enum_ref);

        const enum_values = enum_ref.values();

        if (is_union) {
            if (base_type != .UType)
                return error.InvalidEnum;

            try writer.print("pub const {s} = union(enum(u8))", .{enum_name});
            try writer.writeAll(" {\n");

            for (0..enum_values.len()) |j| {
                const enum_val = enum_values.at(j);
                const enum_val_name = enum_val.name();
                const value = enum_val.value();

                // const union_type = reflection.EnumVal.union_type(self.data, enum_val_ref) orelse
                //     return error.InvalidEnum;

                // if (reflection.Type.base_type(self.data, union_type) != .Obj)
                //     return error.InvalidEnum;

                // const union_type_index = reflection.Type.index(self.data, union_type);
                // const union_type_object = try self.getObject(union_type_index);
                // if (reflection.Object.is_struct(self.data, union_type_object))
                //     return error.InvalidEnum;
                // const union_type_name = reflection.Object.name(self.data, union_type_object);
                // if (!std.mem.eql(u8, enum_val_name, union_type_name))
                //     return error.InvalidEnum;

                if (enum_val.documentation()) |documentation|
                    for (0..documentation.len()) |k|
                        try writer.print("    /// {s}\n", .{documentation.at(k)});

                if (value == 0) {
                    try writer.print("    {s}: void = {d},\n", .{ enum_val_name, value });
                } else {
                    try writer.print("    {s}: {s} = {d},\n", .{ enum_val_name, enum_val_name, value });
                }
            }

            try writer.writeAll("};\n\n");
        } else if (is_bit_flag) {
            const enum_type = try getIntegerName(base_type);

            var flags_buffer: [256]u8 = undefined;
            var flags_writer = std.io.Writer.fixed(&flags_buffer);
            for (0..enum_values.len()) |j| {
                if (j > 0)
                    try flags_writer.writeAll(", ");
                try flags_writer.print("{d}", .{enum_values.at(j).value()});
            }

            const flags = flags_writer.buffered();

            try writer.print(
                \\pub const {s} = packed struct {{
                \\    pub const @"#kind" = flatbuffers.Kind{{
                \\        .BitFlags = .{{
                \\            .backing_integer = {s},
                \\            .flags = &.{{ {s} }},
                \\        }},
                \\    }};
                \\
                \\
            , .{ enum_name, enum_type, flags });

            for (0..enum_values.len()) |j|
                try writer.print("    {s}: bool = false,\n", .{enum_values.at(j).name()});

            try writer.writeAll("};\n\n");
        } else {
            const enum_type = try getIntegerName(base_type);

            try writer.print("pub const {s} = enum({s})", .{ enum_name, enum_type });
            try writer.writeAll(" {\n");
            for (0..enum_values.len()) |j| {
                const enum_val = enum_values.at(j);

                if (enum_val.documentation()) |documentation|
                    for (0..documentation.len()) |k|
                        try writer.print("    /// {s}\n", .{documentation.at(k)});

                try writer.print("    {s} = {d},\n", .{ enum_val.name(), enum_val.value() });
            }

            try writer.writeAll("};\n\n");
        }
    }

    fn writeTableDeclaration(self: *Generator, writer: *std.io.Writer, object: reflection.Object, object_name: []const u8) !void {
        const object_fields = object.fields();
        const object_field_map = try self.getFieldMap(object_fields);

        try writer.print(
            \\pub const {s} = struct {{
            \\    pub const @"#kind" = flatbuffers.Kind.Table;
            \\    @"#ref": flatbuffers.Ref,
            \\
            \\
        , .{object_name});

        for (object_field_map, 0..) |j, field_id| {
            const field = object_fields.at(j);
            const field_name = field.name();
            const field_type = field.type();
            if (field_id != field.id())
                return error.InvalidFieldId;

            const field_offset = field.offset();
            const deprecated = field.deprecated();
            const required = field.required();
            const optional = field.optional();

            if (field_offset != @sizeOf(u32) + @sizeOf(u16) * field_id)
                return error.InvalidFieldOffset;

            if (deprecated) continue;

            const field_base_type = field_type.base_type();
            const field_base_size = field_type.base_size();
            _ = field_base_size;
            _ = optional;

            if (field_base_type == .UType) {
                const next_field_id = field_id + 1;
                if (next_field_id >= object_fields.len)
                    return error.InvalidFieldType;
                const next_field_ref = object_fields.at(object_field_map[next_field_id]);
                const next_field_type = next_field_ref.type();
                const next_field_base_type = next_field_type.base_type();
                if (next_field_base_type != .Union)
                    return error.InvalidFieldType;
                continue;
            }

            if (field.documentation()) |documentation|
                for (0..documentation.len) |k|
                    try writer.print("    /// {s}\n", .{documentation.at(k)});

            try writer.print("    pub fn @\"{s}\"(@\"#self\": {s})", .{ field_name, object_name });

            switch (field_base_type) {
                .Bool => {
                    const default_integer = field.default_integer();
                    try writer.print(
                        \\ bool {{
                        \\        return flatbuffers.decodeScalarField(bool, {d}, @"#self".@"#ref", {});
                        \\    }}
                    , .{ field_id, default_integer != 0 });
                },
                .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                    const default_integer = field.default_integer();
                    const field_enum_index = field_type.index();
                    if (field_enum_index < 0) {
                        const type_name = try getScalarName(field_base_type);
                        try writer.print(
                            \\ {s} {{
                            \\        return flatbuffers.decodeScalarField({s}, {d}, @"#self".@"#ref", {d});
                            \\    }}
                        , .{ type_name, type_name, field_id, default_integer });
                    } else {
                        const field_enum = try self.getEnum(field_enum_index);
                        const enum_name = field_enum.name();
                        const enum_base_type = field_enum.underlying_type().base_type();
                        const is_union = enum_base_type == .UType;
                        const is_bit_flag = hasBitFlags(field_enum);
                        if (is_union) {
                            //
                        } else if (is_bit_flag) {
                            // TODO: default bit flag values
                            try writer.print(
                                \\ {s} {{
                                \\        return flatbuffers.decodeBitFlagsField({s}, {d}, @"#self".@"#ref", {s}{{}});
                                \\    }}
                            , .{ enum_name, enum_name, field_id, enum_name });
                        } else {
                            const default_enum_value = try findEnumValue(field_enum, default_integer);
                            const default_enum_name = default_enum_value.name();

                            try writer.print(
                                \\ {s} {{
                                \\        return flatbuffers.decodeEnumField({s}, {d}, @"#self".@"#ref", {s}.{s});
                                \\    }}
                            , .{ enum_name, enum_name, field_id, enum_name, default_enum_name });
                        }
                    }
                },
                .Float, .Double => {
                    const type_name = try getScalarName(field_base_type);
                    try writer.print(
                        \\ {s} {{
                        \\        return flatbuffers.decodeScalarField({s}, {d}, @"#self".@"#ref", {d});
                        \\    }}
                    , .{ type_name, type_name, field_id, field.default_real() });
                },
                .String => {
                    if (required) {
                        try writer.print(
                            \\ flatbuffers.String {{
                            \\        return flatbuffers.decodeStringField({d}, @"#self".@"#ref") orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?flatbuffers.String {{
                            \\        return flatbuffers.decodeStringField({d}, @"#self".@"#ref");
                            \\    }}
                        , .{field_id});
                    }
                },
                .Vector => {
                    const element = field_type.element();

                    const element_name = name: switch (element) {
                        .Bool, .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong, .Float, .Double => try getScalarName(element),
                        .String => "flatbuffers.String",
                        .Obj => {
                            const element_object_index = field_type.index();
                            const element_object_ref = try self.getObject(element_object_index);
                            break :name element_object_ref.name();
                        },
                        .Array, .UType, .Union, .Vector, .Vector64, .None, .MaxBaseType => return error.InvalidFieldType,
                    };

                    if (required) {
                        try writer.print(
                            \\ flatbuffers.Vector({s}) {{
                            \\        return flatbuffers.decodeVectorField({s}, {d}, @"#self".@"#ref") orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ element_name, element_name, field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?flatbuffers.Vector({s}) {{
                            \\        return flatbuffers.decodeVectorField({s}, {d}, @"#self".@"#ref");
                            \\    }}
                        , .{ element_name, element_name, field_id });
                    }
                },
                .Obj => {
                    const field_object = try self.getObject(field_type.index());
                    const field_object_name = field_object.name();

                    if (required) {
                        try writer.print(
                            \\ {s} {{
                            \\        return flatbuffers.decodeTableField({s}, {d}, @"#self".@"#ref") orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ field_object_name, field_object_name, field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?{s} {{
                            \\        return flatbuffers.decodeTableField({s}, {d}, @"#self".@"#ref");
                            \\    }}
                        , .{ field_object_name, field_object_name, field_id });
                    }
                },
                .UType => unreachable,
                .Union => {
                    if (field_id == 0)
                        return error.InvalidFieldType;
                    const prev_field_id = field_id - 1;
                    const prev_field = object_fields.at(object_field_map[prev_field_id]);
                    const prev_field_type = prev_field.type();
                    const prev_field_base_type = prev_field_type.base_type();
                    if (prev_field_base_type != .UType)
                        return error.InvalidFieldType;

                    const utype_index = field_type.index();
                    if (utype_index != prev_field_type.index())
                        return error.InvalidFieldType;
                    const utype_enum = try self.getEnum(utype_index);
                    const utype_enum_name = utype_enum.name();
                    try writer.print(
                        \\ {s} {{
                        \\        return flatbuffers.decodeUnionField({s}, {d}, {d}, @"#self".@"#ref");
                        \\    }}
                    , .{ utype_enum_name, utype_enum_name, prev_field_id, field_id });
                },
                .Vector64 => {
                    std.log.err("encountered Vector64", .{});
                },
                .Array, .None, .MaxBaseType => return error.InvalidFieldType,
            }

            _ = try writer.splatByte('\n', 2);
        }

        try writer.writeAll("};\n\n");
    }

    fn writeStructDeclaration(
        self: *Generator,
        writer: *std.io.Writer,
        object: reflection.Object,
        object_name: []const u8,
    ) !void {
        const object_fields = object.fields();
        const object_field_map = try self.getFieldMap(object_fields);

        // const object_bytesize = object.bytesize();
        // const object_minalign = object.minalign();

        try writer.print(
            \\pub const {s} = struct {{
            \\    pub const @"#kind" = flatbuffers.Kind.Struct,
            \\
            \\
        , .{object_name});

        for (object_field_map, 0..) |j, field_id| {
            const field = object_fields.at(j);
            const field_name = field.name();
            const field_type = field.type();
            if (field_id != field.id())
                return error.InvalidFieldId;

            // const field_offset = field.offset();

            const required = field.required();
            const optional = field.optional();
            const deprecated = field.deprecated();
            if (required or optional or deprecated)
                return error.InvalidStructField;

            if (field.documentation()) |documentation|
                for (0..documentation.len()) |k|
                    try writer.print("    /// {s}\n", .{documentation.at(k)});

            const field_base_type = field_type.base_type();
            const field_base_size = field_type.base_size();
            _ = field_base_size;

            switch (field_base_type) {
                .Bool, .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong, .Float, .Double => {
                    const scalar_name = try getScalarName(field_base_type);
                    try writer.print("    @\"{s}\": {s},\n", .{ field_name, scalar_name });
                },
                .Array => {
                    @panic("not implemented");
                },
                .Obj => {
                    @panic("not implemented");
                },
                else => return error.InvalidStructField,
            }
        }

        try writer.writeAll("};\n\n");
    }

    fn getFieldMap(self: *Generator, fields: Vector(reflection.Field)) ![]const usize {
        const empty = std.math.maxInt(usize);

        try self.field_id_buffer.resize(self.allocator, fields.len());
        const field_map = self.field_id_buffer.items;

        @memset(field_map, empty);
        for (0..fields.len()) |i| {
            const id = fields.at(i).id();
            if (id >= fields.len())
                return error.InvalidFieldId;
            if (field_map[id] != empty)
                return error.DuplicateFieldId;
            field_map[id] = i;
        }

        return field_map;
    }
};

fn hasBitFlags(enum_ref: reflection.Enum) bool {
    const attributes = enum_ref.attributes() orelse return false;
    const bit_flags = findAttribute(attributes, "bit_flags");
    return bit_flags != null;
}

fn findAttribute(attributes: Vector(reflection.KeyValue), key: [:0]const u8) ?reflection.KeyValue {
    for (0..attributes.len()) |i| {
        const attribute = attributes.at(i);
        const attribute_key = attribute.key();
        if (std.mem.eql(u8, key, attribute_key)) {
            return attribute;
        }
    }

    return null;
}

fn findEnumValue(enum_ref: reflection.Enum, value: i64) !reflection.EnumVal {
    const enum_values = enum_ref.values();
    for (0..enum_values.len()) |k| {
        const enum_val = enum_values.at(k);
        const enum_val_value = enum_val.value();
        if (enum_val_value == value) {
            return enum_val;
        }
    }

    return error.InvalidEnumValue;
}

fn getIntegerName(base_type: reflection.BaseType) ![]const u8 {
    return switch (base_type) {
        .UByte => "u8",
        .Byte => "i8",
        .UShort => "u16",
        .Short => "i16",
        .UInt => "u32",
        .Int => "i32",
        .ULong => "u64",
        .Long => "i64",
        else => return error.InvalidBaseType,
    };
}

fn getScalarName(base_type: reflection.BaseType) ![]const u8 {
    return switch (base_type) {
        .Bool => "bool",
        .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => getIntegerName(base_type),
        .Float => "f32",
        .Double => "f64",
        else => return error.InvalidScalarType,
    };
}

pub fn main() !void {
    var args = std.process.args();

    _ = args.next() orelse unreachable;

    const schema_path = args.next() orelse {
        std.log.err("missing schema path argument", .{});
        return;
    };

    const file = try std.fs.cwd().openFile(schema_path, .{});
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

    var buffer: [4096]u8 = undefined;
    const output = std.fs.File.stdout();
    var output_writer = output.writer(&buffer);

    var generator = try Generator.init(std.heap.c_allocator, @alignCast(data));
    defer generator.deinit();

    try generator.generate(&output_writer.interface);
}

test "simple decoder" {
    var buffer: [4096]u8 = undefined;
    // const data = @embedFile("simple.bfbs");
    const data = @embedFile("reflection.bfbs");
    const log = std.fs.File.stdout();
    var writer = log.writer(&buffer);

    var generator = try Generator.init(@alignCast(data));
    try generator.generate(&writer.interface);
}
