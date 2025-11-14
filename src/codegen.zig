const std = @import("std");

const common = @import("common.zig");
const String = common.String;
const Vector = common.Vector;

const reflection = @import("reflection.zig");

pub fn createDecoder(data: []const u8, writer: *std.io.Writer) !void {
    const schema = reflection.decodeRoot(data);

    try writer.writeAll(
        \\const std = @import("std");
        \\
        \\const common = @import("common.zig");
        \\const Kind = common.Kind;
        \\const String = common.String;
        \\const Vector = common.Vector;
        \\
        \\
    );

    if (reflection.Schema.file_ident(data, schema)) |file_identifier|
        try writer.print("pub const file_identifier = \"{s}\";\n", .{file_identifier});

    if (reflection.Schema.file_ext(data, schema)) |file_extension|
        try writer.print("pub const file_extension = \"{s}\";\n", .{file_extension});

    try writer.writeByte('\n');

    const enums = reflection.Schema.enums(data, schema);
    for (0..enums.len) |i| {
        const enum_item = enums.in(data, i);
        const enum_name = reflection.Enum.name(data, enum_item);
        const underlying_type = reflection.Enum.underlying_type(data, enum_item);
        const underlying_base_type = reflection.Type.base_type(data, underlying_type);
        const enum_type = switch (underlying_base_type) {
            .Byte => "i8",
            .UByte => "u8",
            .Short => "i16",
            .UShort => "u16",
            .Int => "i32",
            .UInt => "u32",
            .Long => "i64",
            .ULong => "u64",
            else => return error.InvalidEnum,
        };

        const is_bit_flag = hasBitFlags(data, enum_item);
        if (is_bit_flag) {
            const enum_values = reflection.Enum.values(data, enum_item);

            var flags_buffer: [256]u8 = undefined;
            var flags_writer = std.io.Writer.fixed(&flags_buffer);
            for (0..enum_values.len) |j| {
                const enum_val = enum_values.in(data, j);
                const enum_val_value = reflection.EnumVal.value(data, enum_val);
                if (j > 0)
                    try flags_writer.writeAll(", ");
                try flags_writer.print("{d}", .{enum_val_value});
            }

            const flags = flags_writer.buffered();

            try writer.print("pub const {s} = packed struct", .{enum_name});
            try writer.writeAll(" {\n");
            try writer.print(
                \\    pub const kind = Kind{{
                \\        .BitFlags = .{{
                \\            .backing_integer = u64,
                \\            .flags = &.{{ {s} }},
                \\        }},
                \\    }};
                \\
                \\
            , .{flags});

            for (0..enum_values.len) |j| {
                const enum_val = enum_values.in(data, j);
                const enum_val_name = reflection.EnumVal.name(data, enum_val);
                try writer.print("    {s}: bool = false,\n", .{enum_val_name});
            }

            try writer.writeAll("};\n\n");
        } else {
            try writer.print("pub const {s} = enum({s})", .{ enum_name, enum_type });
            try writer.writeAll(" {\n");
            const enum_values = reflection.Enum.values(data, enum_item);
            for (0..enum_values.len) |j| {
                const enum_value = enum_values.in(data, j);

                // if (reflection.EnumVal.documentation(data, enum_value)) |documentation|
                //     for (0..documentation.len) |k|
                //         try writer.print("    /// {s}\n", .{documentation.in(data, k)});

                const enum_value_name = reflection.EnumVal.name(data, enum_value);
                const enum_value_value = reflection.EnumVal.value(data, enum_value);

                try writer.print("    {s} = {d},\n", .{ enum_value_name, enum_value_value });
            }

            try writer.writeAll("};\n\n");
        }
    }

    const objects = reflection.Schema.objects(data, schema);
    for (0..objects.len) |i| {
        const object = objects.in(data, i);

        // if (reflection.Object.documentation(data, object)) |documentation|
        //     for (0..documentation.len) |j|
        //         try writer.print("/// {s}\n", .{documentation.in(data, j)});

        const object_name = reflection.Object.name(data, object);
        const object_fields = reflection.Object.fields(data, object);

        if (reflection.Object.is_struct(data, object)) {
            return error.NotImplemented;
        } else {
            try writer.print(
                \\pub const {s}Ref = packed struct {{
                \\    pub const kind = Kind.Table;
                \\    offset: u32,
                \\}};
                \\
                \\
            , .{object_name});

            try writer.print("pub const {s} = struct", .{object_name});
            try writer.writeAll(" {\n");

            for (0..object_fields.len) |j| {
                const field = object_fields.in(data, j);
                const field_name = reflection.Field.name(data, field);
                const field_type = reflection.Field.type(data, field);
                const field_id = reflection.Field.id(data, field);
                const deprecated = reflection.Field.deprecated(data, field);
                const required = reflection.Field.required(data, field);

                if (deprecated) continue;

                // if (field_offset != 4 + 2 * field_id)
                //     return error.InvalidFieldOffset;

                // if (reflection.Field.documentation(data, field)) |documentation|
                //     for (0..documentation.len) |k|
                //         try writer.print("    /// {s}\n", .{documentation.in(data, k)});

                try writer.print("    pub fn @\"{s}\"(data: []const u8, ref: {s}Ref)", .{ field_name, object_name });

                const field_base_type = reflection.Type.base_type(data, field_type);
                // const field_base_size = reflection.Type.base_size(data, field_type);

                switch (field_base_type) {
                    .Bool => {
                        const default_integer = reflection.Field.default_integer(data, field);
                        const default_bool = if (default_integer == 0) "false" else "true";
                        try writer.print(
                            \\ bool {{
                            \\        return common.decodeScalarField({d}, bool, data, ref.offset, {s});
                            \\    }}
                        , .{ field_id, default_bool });
                    },
                    .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong => {
                        // check if enum
                        const default_integer = reflection.Field.default_integer(data, field);
                        const field_enum_index = reflection.Type.index(data, field_type);
                        if (field_enum_index < 0) {
                            const t = try getScalarName(field_base_type);
                            try writer.print(
                                \\ {s} {{
                                \\        return common.decodeScalarField({d}, {s}, data, ref.offset, {d});
                                \\    }}
                            , .{ t, field_id, t, default_integer });
                        } else {
                            if (field_enum_index >= enums.len)
                                return error.InvalidEnumIndex;

                            const field_enum = enums.in(data, @intCast(field_enum_index));
                            const field_enum_name = reflection.Enum.name(data, field_enum);

                            const is_bit_flag = hasBitFlags(data, field_enum);
                            if (is_bit_flag) {
                                // TODO: default bit flag values
                                try writer.print(
                                    \\ {s} {{
                                    \\        return common.decodeBitFlagsField({d}, {s}, data, ref.offset, {s}{{}});
                                    \\    }}
                                , .{ field_enum_name, field_id, field_enum_name, field_enum_name });
                            } else {
                                const default_enum_value = try findEnumValue(data, field_enum, default_integer);
                                const default_enum_name = reflection.EnumVal.name(data, default_enum_value);

                                try writer.print(
                                    \\ {s} {{
                                    \\        return common.decodeEnumField({d}, {s}, data, ref.offset, {s}.{s});
                                    \\    }}
                                , .{ field_enum_name, field_id, field_enum_name, field_enum_name, default_enum_name });
                            }
                        }
                    },
                    .Float, .Double => {
                        const t = try getScalarName(field_base_type);
                        const default_real = reflection.Field.default_real(data, field);
                        try writer.print(
                            \\ {s} {{
                            \\        return common.decodeScalarField({d}, {s}, data, ref.offset, {d});
                            \\    }}
                        , .{ t, field_id, t, default_real });
                    },
                    .String => {
                        if (required) {
                            try writer.print(
                                \\ String {{
                                \\        return common.decodeStringField({d}, data, ref.offset) orelse
                                \\            @panic("missing {s}.{s} field");
                                \\    }}
                            , .{ field_id, object_name, field_name });
                        } else {
                            try writer.print(
                                \\ ?String {{
                                \\        return common.decodeStringField({d}, data, ref.offset);
                                \\    }}
                            , .{field_id});
                        }
                    },
                    .Vector => {
                        var element_name_buffer: [256]u8 = undefined;
                        var element_name_writer = std.io.Writer.fixed(&element_name_buffer);

                        const element = reflection.Type.element(data, field_type);
                        switch (element) {
                            .Bool, .Byte, .UByte, .Short, .UShort, .Int, .UInt, .Long, .ULong, .Float, .Double => {
                                const scalar_name = try getScalarName(field_base_type);
                                try element_name_writer.writeAll(scalar_name);
                            },
                            .String => {
                                try element_name_writer.writeAll("String");
                            },
                            .Vector => return error.InvalidFieldType,
                            .Obj => {
                                const element_object_index = reflection.Type.index(data, field_type);
                                if (element_object_index < 0 or element_object_index >= objects.len)
                                    return error.InvalidObjectIndex;
                                const element_object = objects.in(data, @intCast(element_object_index));
                                const element_object_name = reflection.Object.name(data, element_object);
                                try element_name_writer.writeAll(element_object_name);
                                try element_name_writer.writeAll("Ref");
                            },
                            .Union, .Array, .Vector64 => return error.NotImplemented,
                            .None, .UType, .MaxBaseType => return error.InvalidFieldType,
                        }

                        const element_name = element_name_buffer[0..element_name_writer.end];

                        if (required) {
                            try writer.print(
                                \\ Vector({s}) {{
                                \\        return common.decodeVectorField({d}, {s}, data, ref.offset) orelse
                                \\            @panic("missing {s}.{s} field");
                                \\    }}
                            , .{ element_name, field_id, element_name, object_name, field_name });
                        } else {
                            try writer.print(
                                \\ ?Vector({s}) {{
                                \\        return common.decodeVectorField({d}, {s}, data, ref.offset);
                                \\    }}
                            , .{ element_name, field_id, element_name });
                        }
                    },
                    .Obj => {
                        const field_object_index = reflection.Type.index(data, field_type);
                        if (field_object_index < 0 or field_object_index >= objects.len)
                            return error.InvalidObjectIndex;

                        const field_object = objects.in(data, @intCast(field_object_index));
                        const field_object_name = reflection.Object.name(data, field_object);

                        if (required) {
                            try writer.print(
                                \\ {s}Ref {{
                                \\        return common.decodeTableField({d}, {s}Ref, data, ref.offset) orelse
                                \\            @panic("missing {s}.{s} field");
                                \\    }}
                            , .{ field_object_name, field_id, field_object_name, object_name, field_name });
                        } else {
                            try writer.print(
                                \\ ?{s}Ref {{
                                \\        return common.decodeTableField({d}, {s}Ref, data, ref.offset);
                                \\    }}
                            , .{ field_object_name, field_id, field_object_name });
                        }
                    },
                    .Union => {},
                    .Array => {},
                    .Vector64 => {},
                    .None, .UType, .MaxBaseType => return error.InvalidFieldType,
                }

                _ = try writer.splatByte('\n', 2);
            }

            try writer.writeAll("};\n\n");
        }
    }

    if (reflection.Schema.root_table(data, schema)) |root_table| {
        const root_table_name = reflection.Object.name(data, root_table);
        try writer.print("pub fn decodeRoot(data: []const u8) {s}Ref ", .{root_table_name});
        try writer.writeAll(
            \\{
            \\    const offset = std.mem.readInt(u32, data[0..4], .little);
            \\    return .{ .offset = offset };
            \\}
            \\
        );
    }
}

fn hasBitFlags(data: []const u8, enum_ref: reflection.EnumRef) bool {
    const attributes = reflection.Enum.attributes(data, enum_ref) orelse return false;
    const bit_flags = findAttribute(data, attributes, "bit_flags");
    return bit_flags != null;
}

fn findAttribute(data: []const u8, attributes: Vector(reflection.KeyValueRef), key: [:0]const u8) ?reflection.KeyValueRef {
    for (0..attributes.len) |i| {
        const attribute = attributes.in(data, i);
        const attribute_key = reflection.KeyValue.key(data, attribute);
        if (std.mem.eql(u8, key, attribute_key)) {
            return attribute;
        }
    }

    return null;
}

fn findEnumValue(data: []const u8, enum_ref: reflection.EnumRef, value: i64) !reflection.EnumValRef {
    const enum_values = reflection.Enum.values(data, enum_ref);
    for (0..enum_values.len) |k| {
        const enum_value_ref = enum_values.in(data, k);
        if (reflection.EnumVal.value(data, enum_value_ref) == value) {
            return enum_value_ref;
        }
    }

    return error.InvalidEnumValue;
}

fn getScalarName(base_type: reflection.BaseType) ![]const u8 {
    return switch (base_type) {
        .Bool => "bool",
        .Byte => "i8",
        .UByte => "u8",
        .Short => "i16",
        .UShort => "u16",
        .Int => "i32",
        .UInt => "u32",
        .Long => "i64",
        .ULong => "u64",
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

    try createDecoder(data, &output_writer.interface);
    try output_writer.interface.flush();
}

test "simple decoder" {
    var buffer: [4096]u8 = undefined;
    // const data = @embedFile("simple.bfbs");
    const data = @embedFile("reflection.bfbs");
    const log = std.fs.File.stdout();
    var writer = log.writer(&buffer);

    try createDecoder(data, &writer.interface);
    try writer.interface.flush();
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
