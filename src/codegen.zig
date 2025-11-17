const std = @import("std");

const flatbuffers = @import("flatbuffers.zig");
const String = flatbuffers.String;
const Vector = flatbuffers.Vector;
const Buffer = flatbuffers.Buffer;

const reflection = @import("reflection2.zig");

const Generator = struct {
    data: Buffer,

    root: reflection.SchemaRef,
    enums: Vector(reflection.EnumRef),
    objects: Vector(reflection.ObjectRef),

    field_id_buffer: [1024]usize = undefined,

    pub fn init(data: Buffer) !Generator {
        const schema = reflection.decodeRoot(data);
        const enums = reflection.Schema.enums(data, schema);
        const objects = reflection.Schema.objects(data, schema);

        return Generator{
            .data = data,
            .root = schema,
            .enums = enums,
            .objects = objects,
        };
    }

    pub inline fn deinit(self: *Generator) void {
        _ = self;
    }

    pub fn generate(self: *Generator, writer: *std.io.Writer) !void {
        try writer.writeAll(
            \\const std = @import("std");
            \\
            \\const flatbuffers = @import("flatbuffers.zig");
            \\const String = flatbuffers.String;
            \\const Vector = flatbuffers.Vector;
            \\const Buffer = flatbuffers.Buffer;
            \\
            \\
        );

        if (reflection.Schema.file_ident(self.data, self.root)) |file_identifier|
            try writer.print("pub const file_identifier = \"{s}\";\n", .{file_identifier});

        if (reflection.Schema.file_ext(self.data, self.root)) |file_extension|
            try writer.print("pub const file_extension = \"{s}\";\n", .{file_extension});

        try writer.writeByte('\n');

        for (0..self.enums.len) |i|
            try self.writeEnumDeclaration(writer, self.enums.in(self.data, i));

        for (0..self.objects.len) |i| {
            const object_ref = self.objects.in(self.data, i);
            if (reflection.Object.is_struct(self.data, object_ref)) {
                try self.writeStructDeclaration(writer, object_ref);
            } else {
                try self.writeTableDeclaration(writer, object_ref);
            }
        }

        if (reflection.Schema.root_table(self.data, self.root)) |root_table| {
            const root_table_name = reflection.Object.name(self.data, root_table);
            try writer.print("pub fn decodeRoot(data: Buffer) {s}Ref ", .{root_table_name});
            try writer.writeAll(
                \\{
                \\    const offset = std.mem.readInt(u32, data[0..4], .little);
                \\    return .{ .offset = offset };
                \\}
                \\
            );
        }

        try writer.flush();
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

    fn writeEnumDeclaration(self: *Generator, writer: *std.io.Writer, enum_item: reflection.EnumRef) !void {
        const enum_name = reflection.Enum.name(self.data, enum_item);

        const base_type = reflection.Type.base_type(
            self.data,
            reflection.Enum.underlying_type(self.data, enum_item),
        );

        const enum_type = try getIntegerName(switch (base_type) {
            .UType => reflection.BaseType.UByte,
            else => base_type,
        });

        const is_bit_flag = hasBitFlags(self.data, enum_item);
        if (is_bit_flag) {
            const enum_values = reflection.Enum.values(self.data, enum_item);

            var flags_buffer: [256]u8 = undefined;
            var flags_writer = std.io.Writer.fixed(&flags_buffer);
            for (0..enum_values.len) |j| {
                const enum_val = enum_values.in(self.data, j);
                const enum_val_value = reflection.EnumVal.value(self.data, enum_val);
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
                const enum_val = enum_values.in(self.data, j);
                const enum_val_name = reflection.EnumVal.name(self.data, enum_val);
                try writer.print("    {s}: bool = false,\n", .{enum_val_name});
            }

            try writer.writeAll("};\n\n");
        } else {
            try writer.print("pub const {s} = enum({s})", .{ enum_name, enum_type });
            try writer.writeAll(" {\n");
            const enum_values = reflection.Enum.values(self.data, enum_item);
            for (0..enum_values.len) |j| {
                const enum_value = enum_values.in(self.data, j);

                if (reflection.EnumVal.documentation(self.data, enum_value)) |documentation|
                    for (0..documentation.len) |k|
                        try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

                const enum_value_name = reflection.EnumVal.name(self.data, enum_value);
                const enum_value_value = reflection.EnumVal.value(self.data, enum_value);

                try writer.print("    {s} = {d},\n", .{ enum_value_name, enum_value_value });
            }

            try writer.writeAll("};\n\n");
        }
    }

    fn writeTableDeclaration(self: *Generator, writer: *std.io.Writer, object: reflection.ObjectRef) !void {
        const object_name = reflection.Object.name(self.data, object);
        const object_fields = reflection.Object.fields(self.data, object);
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
            const field = object_fields.in(self.data, j);
            const field_name = reflection.Field.name(self.data, field);
            const field_type = reflection.Field.type(self.data, field);
            if (field_id != reflection.Field.id(self.data, field))
                return error.InvalidFieldId;

            const field_offset = reflection.Field.offset(self.data, field);
            const deprecated = reflection.Field.deprecated(self.data, field);
            const required = reflection.Field.required(self.data, field);
            // const optional = reflection.Field.optional(self.data, field);

            if (field_offset != @sizeOf(u32) + @sizeOf(u16) * field_id)
                return error.InvalidFieldOffset;

            if (deprecated) continue;

            if (reflection.Field.documentation(self.data, field)) |documentation|
                for (0..documentation.len) |k|
                    try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

            try writer.print("    pub fn @\"{s}\"(data: Buffer, ref: {s}Ref)", .{ field_name, object_name });

            const field_base_type = reflection.Type.base_type(self.data, field_type);
            const field_base_size = reflection.Type.base_size(self.data, field_type);
            _ = field_base_size;

            switch (field_base_type) {
                .Bool => {
                    const default_integer = reflection.Field.default_integer(self.data, field);
                    try writer.print(
                        \\ bool {{
                        \\        const field_id = {d};
                        \\        return flatbuffers.decodeScalarField(field_id, bool, data, ref.offset, {});
                        \\    }}
                    , .{ field_id, default_integer != 0 });
                },
                .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                    const default_integer = reflection.Field.default_integer(self.data, field);
                    const field_enum_index = reflection.Type.index(self.data, field_type);
                    if (field_enum_index < 0) {
                        const type_name = try getScalarName(field_base_type);
                        try writer.print(
                            \\ {s} {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeScalarField(field_id, {s}, data, ref.offset, {d});
                            \\    }}
                        , .{ type_name, field_id, type_name, default_integer });
                    } else {
                        const field_enum = try self.getEnum(field_enum_index);
                        const field_enum_name = reflection.Enum.name(self.data, field_enum);

                        const is_bit_flag = hasBitFlags(self.data, field_enum);
                        if (is_bit_flag) {
                            // TODO: default bit flag values
                            try writer.print(
                                \\ {s} {{
                                \\        const field_id = {d};
                                \\        return flatbuffers.decodeBitFlagsField(field_id, {s}, data, ref.offset, {s}{{}});
                                \\    }}
                            , .{ field_enum_name, field_id, field_enum_name, field_enum_name });
                        } else {
                            const default_enum_value = try findEnumValue(self.data, field_enum, default_integer);
                            const default_enum_name = reflection.EnumVal.name(self.data, default_enum_value);

                            try writer.print(
                                \\ {s} {{
                                \\        const field_id = {d};
                                \\        return flatbuffers.decodeEnumField(field_id, {s}, data, ref.offset, {s}.{s});
                                \\    }}
                            , .{ field_enum_name, field_id, field_enum_name, field_enum_name, default_enum_name });
                        }
                    }
                },
                .Float, .Double => {
                    const type_name = try getScalarName(field_base_type);
                    const default_real = reflection.Field.default_real(self.data, field);
                    try writer.print(
                        \\ {s} {{
                        \\        const field_id = {d};
                        \\        return flatbuffers.decodeScalarField(field_id, {s}, data, ref.offset, {d});
                        \\    }}
                    , .{ type_name, field_id, type_name, default_real });
                },
                .String => {
                    if (required) {
                        try writer.print(
                            \\ flatbuffers.String {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeStringField(field_id, data, ref.offset) orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ field_id, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?flatbuffers.String {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeStringField(field_id, data, ref.offset);
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
                        .String => {
                            try element_name_writer.writeAll("flatbuffers.String");
                        },
                        .Vector => return error.InvalidFieldType,
                        .Obj => {
                            const element_object_index = reflection.Type.index(self.data, field_type);
                            const element_object = try self.getObject(element_object_index);
                            const element_object_name = reflection.Object.name(self.data, element_object);
                            try element_name_writer.print("{s}Ref", .{element_object_name});
                        },
                        .Union, .Array, .Vector64 => return error.NotImplemented,
                        .None, .UType, .MaxBaseType => return error.InvalidFieldType,
                    }

                    const element_name = element_name_buffer[0..element_name_writer.end];

                    if (required) {
                        try writer.print(
                            \\ flatbuffers.Vector({s}) {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeVectorField(field_id, {s}, data, ref.offset) orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ element_name, field_id, element_name, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?flatbuffers.Vector({s}) {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeVectorField(field_id, {s}, data, ref.offset);
                            \\    }}
                        , .{ element_name, field_id, element_name });
                    }
                },
                .Obj => {
                    const field_object_index = reflection.Type.index(self.data, field_type);
                    const field_object = try self.getObject(field_object_index);
                    const field_object_name = reflection.Object.name(self.data, field_object);

                    if (required) {
                        try writer.print(
                            \\ {s}Ref {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeTableField(field_id, {s}Ref, data, ref.offset) orelse
                            \\            @panic("missing {s}.{s} field");
                            \\    }}
                        , .{ field_object_name, field_id, field_object_name, object_name, field_name });
                    } else {
                        try writer.print(
                            \\ ?{s}Ref {{
                            \\        const field_id = {d};
                            \\        return flatbuffers.decodeTableField(field_id, {s}Ref, data, ref.offset);
                            \\    }}
                        , .{ field_object_name, field_id, field_object_name });
                    }
                },
                .UType => {
                    std.log.err("encountered UType", .{});
                },
                .Union => {
                    std.log.err("encountered Union", .{});
                },
                .Array => {
                    std.log.err("encountered Array", .{});
                },
                .Vector64 => {
                    std.log.err("encountered Vector64", .{});
                },
                .None, .MaxBaseType => return error.InvalidFieldType,
            }

            _ = try writer.splatByte('\n', 2);
        }

        try writer.writeAll("};\n\n");
    }

    fn writeStructDeclaration(self: *Generator, writer: *std.io.Writer, object: reflection.ObjectRef) !void {
        const object_name = reflection.Object.name(self.data, object);
        const object_fields = reflection.Object.fields(self.data, object);
        const object_field_map = try self.getFieldMap(object_fields);

        // const object_bytesize = reflection.Object.bytesize(data, object);
        // const object_minalign = reflection.Object.minalign(data, object);

        try writer.print("pub const @\"{s}\" = struct", .{object_name});
        try writer.writeAll(" {\n");

        for (object_field_map, 0..) |j, field_id| {
            const field = object_fields.in(self.data, j);
            const field_name = reflection.Field.name(self.data, field);
            const field_type = reflection.Field.type(self.data, field);
            if (field_id != reflection.Field.id(self.data, field))
                return error.InvalidFieldId;

            // const field_offset = reflection.Field.offset(self.data, field);

            const required = reflection.Field.required(self.data, field);
            const optional = reflection.Field.optional(self.data, field);
            const deprecated = reflection.Field.deprecated(self.data, field);
            if (required or optional or deprecated)
                return error.InvalidStructField;

            if (reflection.Field.documentation(self.data, field)) |documentation|
                for (0..documentation.len) |k|
                    try writer.print("    /// {s}\n", .{documentation.in(self.data, k)});

            const field_base_type = reflection.Type.base_type(self.data, field_type);
            const field_base_size = reflection.Type.base_size(self.data, field_type);
            _ = field_base_size;

            switch (field_base_type) {
                .Bool, .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong, .Float, .Double => {
                    const scalar_name = try getScalarName(field_base_type);
                    try writer.print("    @\"{s}\": {s}\n", .{ field_name, scalar_name });
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
        const field_map = self.field_id_buffer[0..fields.len];
        @memset(field_map, empty);
        for (0..fields.len) |i| {
            const field = fields.in(self.data, i);
            const field_id = reflection.Field.id(self.data, field);
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
        const enum_value_ref = enum_values.in(data, k);
        if (reflection.EnumVal.value(data, enum_value_ref) == value) {
            return enum_value_ref;
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

    var generator = try Generator.init(@alignCast(data));
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
