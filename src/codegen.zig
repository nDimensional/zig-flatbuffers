const std = @import("std");

const flatbuffers = @import("flatbuffers.zig");
const String = flatbuffers.String;
const Vector = flatbuffers.Vector;
const Buffer = flatbuffers.Buffer;

const reflection = @import("reflection.zig").reflection;
const decodeRoot = @import("reflection.zig").decodeRoot;

const Generator = struct {
    allocator: std.mem.Allocator,
    data: Buffer,

    root: reflection.SchemaRef,
    enums: Vector(reflection.EnumRef),
    objects: Vector(reflection.ObjectRef),

    field_id_buffer: std.ArrayList(usize),
    namespace_prefix_map: std.StringArrayHashMapUnmanaged(usize),

    pub fn init(allocator: std.mem.Allocator, data: Buffer) !Generator {
        const schema = decodeRoot(data);
        const enums = reflection.Schema.enums(data, schema);
        const objects = reflection.Schema.objects(data, schema);

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

        if (reflection.Schema.file_ident(self.data, self.root)) |file_identifier|
            try writer.print("pub const file_identifier = \"{s}\";\n", .{file_identifier});

        if (reflection.Schema.file_ext(self.data, self.root)) |file_extension|
            try writer.print("pub const file_extension = \"{s}\";\n", .{file_extension});

        try writer.writeByte('\n');

        // here we build a list of all partial namespace prefixes, e.g.
        // 0: "org"
        // 1: "org.apache"
        // 2: "org.apache.arrow"
        // 3: "org.apache.arrow.flatbuf"
        // ... which will get sorted and each written as a nested namespace struct.

        for (0..self.enums.len) |i| {
            const enum_ref = self.enums.in(self.data, i);
            const enum_name = reflection.Enum.name(self.data, enum_ref);
            try self.addNamespacePrefix(enum_name);
        }

        for (0..self.objects.len) |i| {
            const object_ref = self.objects.in(self.data, i);
            const object_name = reflection.Object.name(self.data, object_ref);
            try self.addNamespacePrefix(object_name);
        }

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

            for (0..self.enums.len) |j| {
                const enum_ref = self.enums.in(self.data, j);
                const enum_name = reflection.Enum.name(self.data, enum_ref);
                const prefix_end = std.mem.lastIndexOfScalar(u8, enum_name, '.') orelse continue;
                if (std.mem.eql(u8, prefix, enum_name[0 .. prefix_end + 1])) {
                    try self.writeEnumDeclaration(writer, enum_ref, enum_name[prefix.len..]);
                }
            }

            for (0..self.objects.len) |j| {
                const object_ref = self.objects.in(self.data, j);
                const object_name = reflection.Object.name(self.data, object_ref);
                const prefix_end = std.mem.lastIndexOfScalar(u8, object_name, '.') orelse continue;
                if (std.mem.eql(u8, prefix, object_name[0 .. prefix_end + 1])) {
                    if (reflection.Object.is_struct(self.data, object_ref)) {
                        try self.writeStructDeclaration(writer, object_ref, object_name[prefix.len..]);
                    } else {
                        try self.writeTableDeclaration(writer, object_ref, object_name[prefix.len..]);
                    }
                }
            }

            var closing_count = level;
            if (i + 1 < count)
                closing_count -= @min(level, values[i + 1]);

            for (0..closing_count) |_|
                try writer.writeAll("};\n");
        }

        if (reflection.Schema.root_table(self.data, self.root)) |root_table| {
            try writer.print(
                \\
                \\pub fn decodeRoot(data: flatbuffers.Buffer) {s}Ref {{
                \\    const offset = std.mem.readInt(u32, data[0..4], .little);
                \\    return .{{ .offset = offset }};
                \\}}
                \\
            , .{reflection.Object.name(self.data, root_table)});

            try writer.writeAll(
                \\
                \\pub fn validateRoot(data: flatbuffers.Buffer) !void {
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

    inline fn getEnum(self: *Generator, enum_index: i32) !reflection.EnumRef {
        if (enum_index < 0 or enum_index >= self.enums.len)
            return error.InvalidEnumIndex;

        return self.enums.in(self.data, @intCast(enum_index));
    }

    inline fn getObject(self: *Generator, object_index: i32) !reflection.ObjectRef {
        if (object_index < 0 or object_index >= self.objects.len)
            return error.InvalidEnumIndex;

        return self.objects.in(self.data, @intCast(object_index));
    }

    fn writeEnumDeclaration(
        self: *Generator,
        writer: *std.io.Writer,
        enum_ref: reflection.EnumRef,
        enum_name: []const u8,
    ) !void {
        const base_type = reflection.Type.base_type(
            self.data,
            reflection.Enum.underlying_type(self.data, enum_ref),
        );

        const is_union = reflection.Enum.is_union(self.data, enum_ref);
        const is_bit_flag = hasBitFlags(self.data, enum_ref);

        const enum_values = reflection.Enum.values(self.data, enum_ref);

        if (is_union) {
            if (base_type != .UType)
                return error.InvalidEnum;

            try writer.print("pub const {s} = union(enum(u8))", .{enum_name});
            try writer.writeAll(" {\n");

            for (0..enum_values.len) |j| {
                const enum_val_ref = enum_values.in(self.data, j);
                const enum_val_name = reflection.EnumVal.name(self.data, enum_val_ref);
                const enum_val_value = reflection.EnumVal.value(self.data, enum_val_ref);

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

                if (reflection.EnumVal.documentation(self.data, enum_val_ref)) |documentation|
                    for (0..documentation.len) |k|
                        try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

                if (enum_val_value == 0) {
                    try writer.print("    {s}: void = {d},\n", .{ enum_val_name, enum_val_value });
                } else {
                    try writer.print("    {s}: {s}Ref = {d},\n", .{ enum_val_name, enum_val_name, enum_val_value });
                }
            }

            try writer.writeAll("};\n\n");
        } else if (is_bit_flag) {
            const enum_type = try getIntegerName(base_type);

            var flags_buffer: [256]u8 = undefined;
            var flags_writer = std.io.Writer.fixed(&flags_buffer);
            for (0..enum_values.len) |j| {
                const enum_val_ref = enum_values.in(self.data, j);
                const enum_val_value = reflection.EnumVal.value(self.data, enum_val_ref);
                if (j > 0)
                    try flags_writer.writeAll(", ");
                try flags_writer.print("{d}", .{enum_val_value});
            }

            const flags = flags_writer.buffered();

            try writer.print("pub const {s} = packed struct", .{enum_name});
            try writer.writeAll(" {\n");
            try writer.print(
                \\    pub const kind = flatbuffers.Kind{{
                \\        .BitFlags = .{{
                \\            .backing_integer = {s},
                \\            .flags = &.{{ {s} }},
                \\        }},
                \\    }};
                \\
                \\
            , .{ enum_type, flags });

            for (0..enum_values.len) |j| {
                const enum_val_ref = enum_values.in(self.data, j);
                const enum_val_name = reflection.EnumVal.name(self.data, enum_val_ref);
                try writer.print("    {s}: bool = false,\n", .{enum_val_name});
            }

            try writer.writeAll("};\n\n");
        } else {
            const enum_type = try getIntegerName(base_type);

            try writer.print("pub const {s} = enum({s})", .{ enum_name, enum_type });
            try writer.writeAll(" {\n");
            for (0..enum_values.len) |j| {
                const enum_val_ref = enum_values.in(self.data, j);

                if (reflection.EnumVal.documentation(self.data, enum_val_ref)) |documentation|
                    for (0..documentation.len) |k|
                        try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

                const enum_val_name = reflection.EnumVal.name(self.data, enum_val_ref);
                const enum_val_value = reflection.EnumVal.value(self.data, enum_val_ref);

                try writer.print("    {s} = {d},\n", .{ enum_val_name, enum_val_value });
            }

            try writer.writeAll("};\n\n");
        }
    }

    fn writeTableDeclaration(self: *Generator, writer: *std.io.Writer, object_ref: reflection.ObjectRef, object_name: []const u8) !void {
        const object_fields = reflection.Object.fields(self.data, object_ref);
        const object_field_map = try self.getFieldMap(object_fields);

        try writer.print(
            \\pub const {s}Ref = packed struct {{
            \\    pub const kind = flatbuffers.Kind.Table;
            \\    offset: u32,
            \\}};
            \\
            \\
        , .{object_name});

        try writer.print("pub const {s} = struct", .{object_name});
        try writer.writeAll(" {\n");

        for (object_field_map, 0..) |j, field_id| {
            const field_ref = object_fields.in(self.data, j);
            const field_name = reflection.Field.name(self.data, field_ref);
            const field_type = reflection.Field.type(self.data, field_ref);
            if (field_id != reflection.Field.id(self.data, field_ref))
                return error.InvalidFieldId;

            const field_offset = reflection.Field.offset(self.data, field_ref);
            const deprecated = reflection.Field.deprecated(self.data, field_ref);
            const required = reflection.Field.required(self.data, field_ref);
            const optional = reflection.Field.optional(self.data, field_ref);

            if (field_offset != @sizeOf(u32) + @sizeOf(u16) * field_id)
                return error.InvalidFieldOffset;

            if (deprecated) continue;

            const field_base_type = reflection.Type.base_type(self.data, field_type);
            const field_base_size = reflection.Type.base_size(self.data, field_type);
            _ = field_base_size;
            _ = optional;

            if (field_base_type == .UType) {
                const next_field_id = field_id + 1;
                if (next_field_id >= object_fields.len)
                    return error.InvalidFieldType;
                const next_field_ref = object_fields.in(self.data, object_field_map[next_field_id]);
                const next_field_type = reflection.Field.type(self.data, next_field_ref);
                const next_field_base_type = reflection.Type.base_type(self.data, next_field_type);
                if (next_field_base_type != .Union)
                    return error.InvalidFieldType;
                continue;
            }

            if (reflection.Field.documentation(self.data, field_ref)) |documentation|
                for (0..documentation.len) |k|
                    try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

            try writer.print("    pub fn @\"{s}\"(data: flatbuffers.Buffer, ref: {s}Ref)", .{ field_name, object_name });

            switch (field_base_type) {
                .Bool => {
                    const default_integer = reflection.Field.default_integer(self.data, field_ref);
                    try writer.print(
                        \\ bool {{
                        \\        return flatbuffers.decodeScalarField(bool, {d}, data, ref.offset, {});
                        \\    }}
                    , .{ field_id, default_integer != 0 });
                },
                .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                    const default_integer = reflection.Field.default_integer(self.data, field_ref);
                    const field_enum_index = reflection.Type.index(self.data, field_type);
                    if (field_enum_index < 0) {
                        const type_name = try getScalarName(field_base_type);
                        try writer.print(
                            \\ {s} {{
                            \\        return flatbuffers.decodeScalarField({s}, {d}, data, ref.offset, {d});
                            \\    }}
                        , .{ type_name, type_name, field_id, default_integer });
                    } else {
                        const field_enum_ref = try self.getEnum(field_enum_index);
                        const field_enum_name = reflection.Enum.name(self.data, field_enum_ref);
                        const field_enum_type = reflection.Enum.underlying_type(self.data, field_enum_ref);
                        const field_enum_base_type = reflection.Type.base_type(self.data, field_enum_type);
                        const is_union = field_enum_base_type == .UType;
                        const is_bit_flag = hasBitFlags(self.data, field_enum_ref);
                        if (is_union) {
                            //
                        } else if (is_bit_flag) {
                            // TODO: default bit flag values
                            try writer.print(
                                \\ {s} {{
                                \\        return flatbuffers.decodeBitFlagsField({s}, {d}, data, ref.offset, {s}{{}});
                                \\    }}
                            , .{ field_enum_name, field_enum_name, field_id, field_enum_name });
                        } else {
                            const default_enum_value = try findEnumValue(self.data, field_enum_ref, default_integer);
                            const default_enum_name = reflection.EnumVal.name(self.data, default_enum_value);

                            try writer.print(
                                \\ {s} {{
                                \\        return flatbuffers.decodeEnumField({s}, {d}, data, ref.offset, {s}.{s});
                                \\    }}
                            , .{ field_enum_name, field_enum_name, field_id, field_enum_name, default_enum_name });
                        }
                    }
                },
                .Float, .Double => {
                    const type_name = try getScalarName(field_base_type);
                    const default_real = reflection.Field.default_real(self.data, field_ref);
                    try writer.print(
                        \\ {s} {{
                        \\        return flatbuffers.decodeScalarField({s}, {d}, data, ref.offset, {d});
                        \\    }}
                    , .{ type_name, type_name, field_id, default_real });
                },
                .String => {
                    if (required) {
                        try writer.print(
                            \\ flatbuffers.String {{
                            \\        return flatbuffers.decodeStringField({d}, data, ref.offset) orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?flatbuffers.String {{
                            \\        return flatbuffers.decodeStringField({d}, data, ref.offset);
                            \\    }}
                        , .{field_id});
                    }
                },
                .Vector => {
                    var element_name_buffer: [256]u8 = undefined;
                    var element_name_writer = std.io.Writer.fixed(&element_name_buffer);

                    const element = reflection.Type.element(self.data, field_type);
                    switch (element) {
                        .Bool, .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong, .Float, .Double => {
                            const scalar_name = try getScalarName(element);
                            try element_name_writer.writeAll(scalar_name);
                        },
                        .String => try element_name_writer.writeAll("flatbuffers.String"),
                        .Obj => {
                            const element_object_index = reflection.Type.index(self.data, field_type);
                            const element_object_ref = try self.getObject(element_object_index);
                            const element_object_name = reflection.Object.name(self.data, element_object_ref);
                            try element_name_writer.print("{s}Ref", .{element_object_name});
                        },
                        .Array, .UType, .Union, .Vector, .Vector64, .None, .MaxBaseType => return error.InvalidFieldType,
                    }

                    const element_name = element_name_buffer[0..element_name_writer.end];

                    if (required) {
                        try writer.print(
                            \\ flatbuffers.Vector({s}) {{
                            \\        return flatbuffers.decodeVectorField({s}, {d}, data, ref.offset) orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ element_name, element_name, field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?flatbuffers.Vector({s}) {{
                            \\        return flatbuffers.decodeVectorField({s}, {d}, data, ref.offset);
                            \\    }}
                        , .{ element_name, element_name, field_id });
                    }
                },
                .Obj => {
                    const field_object_index = reflection.Type.index(self.data, field_type);
                    const field_object_ref = try self.getObject(field_object_index);
                    const field_object_name = reflection.Object.name(self.data, field_object_ref);

                    if (required) {
                        try writer.print(
                            \\ {s}Ref {{
                            \\        return flatbuffers.decodeTableField({s}Ref, {d}, data, ref.offset) orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ field_object_name, field_object_name, field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?{s}Ref {{
                            \\        return flatbuffers.decodeTableField({s}Ref, {d}, data, ref.offset);
                            \\    }}
                        , .{ field_object_name, field_object_name, field_id });
                    }
                },
                .UType => unreachable,
                .Union => {
                    if (field_id == 0)
                        return error.InvalidFieldType;
                    const prev_field_id = field_id - 1;
                    const prev_field_ref = object_fields.in(self.data, object_field_map[prev_field_id]);
                    const prev_field_type = reflection.Field.type(self.data, prev_field_ref);
                    const prev_field_base_type = reflection.Type.base_type(self.data, prev_field_type);
                    if (prev_field_base_type != .UType)
                        return error.InvalidFieldType;

                    const utype_index = reflection.Type.index(self.data, field_type);
                    if (utype_index != reflection.Type.index(self.data, prev_field_type))
                        return error.InvalidFieldType;
                    const utype_enum_ref = try self.getEnum(utype_index);
                    const utype_enum_name = reflection.Enum.name(self.data, utype_enum_ref);
                    try writer.print(
                        \\ {s} {{
                        \\        return flatbuffers.decodeUnionField({s}, {d}, {d}, data, ref.offset);
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
        object_ref: reflection.ObjectRef,
        object_name: []const u8,
    ) !void {
        const object_fields = reflection.Object.fields(self.data, object_ref);
        const object_field_map = try self.getFieldMap(object_fields);

        // const object_bytesize = reflection.Object.bytesize(data, object);
        // const object_minalign = reflection.Object.minalign(data, object);

        try writer.print("pub const @\"{s}\" = struct", .{object_name});
        try writer.writeAll(" {\n");

        for (object_field_map, 0..) |j, field_id| {
            const field_ref = object_fields.in(self.data, j);
            const field_name = reflection.Field.name(self.data, field_ref);
            const field_type = reflection.Field.type(self.data, field_ref);
            if (field_id != reflection.Field.id(self.data, field_ref))
                return error.InvalidFieldId;

            // const field_offset = reflection.Field.offset(self.data, field);

            const required = reflection.Field.required(self.data, field_ref);
            const optional = reflection.Field.optional(self.data, field_ref);
            const deprecated = reflection.Field.deprecated(self.data, field_ref);
            if (required or optional or deprecated)
                return error.InvalidStructField;

            if (reflection.Field.documentation(self.data, field_ref)) |documentation|
                for (0..documentation.len) |k|
                    try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

            const field_base_type = reflection.Type.base_type(self.data, field_type);
            const field_base_size = reflection.Type.base_size(self.data, field_type);
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

    fn getFieldMap(self: *Generator, fields: Vector(reflection.FieldRef)) ![]const usize {
        const empty = std.math.maxInt(usize);

        try self.field_id_buffer.resize(self.allocator, fields.len);
        const field_map = self.field_id_buffer.items;

        @memset(field_map, empty);
        for (0..fields.len) |i| {
            const field_ref = fields.in(self.data, i);
            const field_id = reflection.Field.id(self.data, field_ref);
            if (field_id >= fields.len)
                return error.InvalidFieldId;
            if (field_map[field_id] != empty)
                return error.DuplicateFieldId;
            field_map[field_id] = i;
        }

        return field_map;
    }
};

fn hasBitFlags(data: Buffer, enum_ref: reflection.EnumRef) bool {
    const attributes = reflection.Enum.attributes(data, enum_ref) orelse return false;
    const bit_flags = findAttribute(data, attributes, "bit_flags");
    return bit_flags != null;
}

fn findAttribute(data: Buffer, attributes: Vector(reflection.KeyValueRef), key: [:0]const u8) ?reflection.KeyValueRef {
    for (0..attributes.len) |i| {
        const attribute = attributes.in(data, i);
        const attribute_key = reflection.KeyValue.key(data, attribute);
        if (std.mem.eql(u8, key, attribute_key)) {
            return attribute;
        }
    }

    return null;
}

fn findEnumValue(data: Buffer, enum_ref: reflection.EnumRef, value: i64) !reflection.EnumValRef {
    const enum_values = reflection.Enum.values(data, enum_ref);
    for (0..enum_values.len) |k| {
        const enum_val_ref = enum_values.in(data, k);
        const enum_val_value = reflection.EnumVal.value(data, enum_val_ref);
        if (enum_val_value == value) {
            return enum_val_ref;
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

// test "simple.bfbs" {
//     const data = @embedFile("simple.bfbs");

//     std.log.warn("simple: {x}", .{data});

//     const schema = reflection.decodeRoot(data);
//     std.log.warn("schema: {any}", .{schema});

//     const file_ident = reflection.Schema.file_ident(data, schema);
//     std.log.warn("file ident: {s}", .{file_ident orelse "(none)"});

//     const objects =  reflection.Schema.objects(data, schema);
//     std.log.warn("objects: {any}", .{objects});

//     for (0..objects.len) |i| {
//         const object = objects.in(data, i);
//         const object_name =  reflection.Object.name(data, object);
//         std.log.warn("object {d}: {s}", .{ i, object_name });

//         const fields =  reflection.Object.fields(data, object);
//         for (0..fields.len) |j| {
//             const field = fields.in(data, j);
//             const field_name =  reflection.Field.name(data, field);
//             std.log.warn("  field {d}: {s}", .{ j, field_name });
//         }
//     }
// }

// test "reflection.bfbs" {
//     const data = @embedFile("reflection.bfbs");

//     const schema = reflection.decodeRoot(data);
//     std.log.warn("schema: {any}", .{schema});

//     if (reflection.Schema.file_ident(data, schema)) |file_identifier|
//         std.log.warn("file identifier: {s}", .{file_identifier});

//     if (reflection.Schema.file_ext(data, schema)) |file_extension|
//         std.log.warn("file extension: {s}", .{file_extension});

//     const objects =  reflection.Schema.objects(data, schema);
//     std.log.warn("objects: {any}", .{objects});

//     for (0..objects.len) |i| {
//         const object = objects.in(data, i);
//         const object_name =  reflection.Object.name(data, object);
//         std.log.warn("object {d}: {s}", .{ i, object_name });

//         const fields =  reflection.Object.fields(data, object);
//         for (0..fields.len) |j| {
//             const field = fields.in(data, j);
//             const field_name =  reflection.Field.name(data, field);
//             std.log.warn("  field {d}: {s}", .{ j, field_name });
//         }
//     }
// }
