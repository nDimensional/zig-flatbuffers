const std = @import("std");

const flatbuffers = @import("flatbuffers.zig");

pub const file_identifier = "BFBS";
pub const file_extension = "bfbs";

pub const reflection = struct {
    pub const AdvancedFeatures = packed struct {
        pub const kind = flatbuffers.Kind{
            .BitFlags = .{
                .backing_integer = u64,
                .flags = &.{ 1, 2, 4, 8 },
            },
        };

        AdvancedArrayFeatures: bool = false,
        AdvancedUnionFeatures: bool = false,
        OptionalScalars: bool = false,
        DefaultVectorsAndStrings: bool = false,
    };

    pub const BaseType = enum(i8) {
        None = 0,
        UType = 1,
        Bool = 2,
        Byte = 3,
        UByte = 4,
        Short = 5,
        UShort = 6,
        Int = 7,
        UInt = 8,
        Long = 9,
        ULong = 10,
        Float = 11,
        Double = 12,
        String = 13,
        Vector = 14,
        Obj = 15,
        Union = 16,
        Array = 17,
        Vector64 = 18,
        MaxBaseType = 19,
    };

    pub const EnumRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const Enum = struct {
        pub fn name(data: flatbuffers.Buffer, ref: EnumRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing Enum.name field");
        }

        pub fn values(data: flatbuffers.Buffer, ref: EnumRef) flatbuffers.Vector(reflection.EnumValRef) {
            return flatbuffers.decodeVectorField(reflection.EnumValRef, 1, data, ref.offset) orelse
                @panic("missing Enum.values field");
        }

        pub fn is_union(data: flatbuffers.Buffer, ref: EnumRef) bool {
            return flatbuffers.decodeScalarField(bool, 2, data, ref.offset, false);
        }

        pub fn underlying_type(data: flatbuffers.Buffer, ref: EnumRef) reflection.TypeRef {
            return flatbuffers.decodeTableField(reflection.TypeRef, 3, data, ref.offset) orelse
                @panic("missing Enum.underlying_type field");
        }

        pub fn attributes(data: flatbuffers.Buffer, ref: EnumRef) ?flatbuffers.Vector(reflection.KeyValueRef) {
            return flatbuffers.decodeVectorField(reflection.KeyValueRef, 4, data, ref.offset);
        }

        ///  Array of documentation comments for the enum
        pub fn documentation(data: flatbuffers.Buffer, ref: EnumRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 5, data, ref.offset);
        }

        ///  File that this Enum is declared in.
        pub fn declaration_file(data: flatbuffers.Buffer, ref: EnumRef) ?flatbuffers.String {
            return flatbuffers.decodeStringField(6, data, ref.offset);
        }
    };

    pub const EnumValRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const EnumVal = struct {
        pub fn name(data: flatbuffers.Buffer, ref: EnumValRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing EnumVal.name field");
        }

        pub fn value(data: flatbuffers.Buffer, ref: EnumValRef) i64 {
            return flatbuffers.decodeScalarField(i64, 1, data, ref.offset, 0);
        }

        pub fn union_type(data: flatbuffers.Buffer, ref: EnumValRef) ?reflection.TypeRef {
            return flatbuffers.decodeTableField(reflection.TypeRef, 3, data, ref.offset);
        }

        ///  Array of documentation comments for the enum value
        pub fn documentation(data: flatbuffers.Buffer, ref: EnumValRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 4, data, ref.offset);
        }

        pub fn attributes(data: flatbuffers.Buffer, ref: EnumValRef) ?flatbuffers.Vector(reflection.KeyValueRef) {
            return flatbuffers.decodeVectorField(reflection.KeyValueRef, 5, data, ref.offset);
        }
    };

    pub const FieldRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const Field = struct {
        pub fn name(data: flatbuffers.Buffer, ref: FieldRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing Field.name field");
        }

        pub fn @"type"(data: flatbuffers.Buffer, ref: FieldRef) reflection.TypeRef {
            return flatbuffers.decodeTableField(reflection.TypeRef, 1, data, ref.offset) orelse
                @panic("missing Field.type field");
        }

        pub fn id(data: flatbuffers.Buffer, ref: FieldRef) u16 {
            return flatbuffers.decodeScalarField(u16, 2, data, ref.offset, 0);
        }

        pub fn offset(data: flatbuffers.Buffer, ref: FieldRef) u16 {
            return flatbuffers.decodeScalarField(u16, 3, data, ref.offset, 0);
        }

        pub fn default_integer(data: flatbuffers.Buffer, ref: FieldRef) i64 {
            return flatbuffers.decodeScalarField(i64, 4, data, ref.offset, 0);
        }

        pub fn default_real(data: flatbuffers.Buffer, ref: FieldRef) f64 {
            return flatbuffers.decodeScalarField(f64, 5, data, ref.offset, 0);
        }

        pub fn deprecated(data: flatbuffers.Buffer, ref: FieldRef) bool {
            return flatbuffers.decodeScalarField(bool, 6, data, ref.offset, false);
        }

        pub fn required(data: flatbuffers.Buffer, ref: FieldRef) bool {
            return flatbuffers.decodeScalarField(bool, 7, data, ref.offset, false);
        }

        pub fn key(data: flatbuffers.Buffer, ref: FieldRef) bool {
            return flatbuffers.decodeScalarField(bool, 8, data, ref.offset, false);
        }

        pub fn attributes(data: flatbuffers.Buffer, ref: FieldRef) ?flatbuffers.Vector(reflection.KeyValueRef) {
            return flatbuffers.decodeVectorField(reflection.KeyValueRef, 9, data, ref.offset);
        }

        ///  Array of documentation comments for the field
        pub fn documentation(data: flatbuffers.Buffer, ref: FieldRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 10, data, ref.offset);
        }

        pub fn optional(data: flatbuffers.Buffer, ref: FieldRef) bool {
            return flatbuffers.decodeScalarField(bool, 11, data, ref.offset, false);
        }

        ///  Number of padding octets to always add after this field. Structs only.
        pub fn padding(data: flatbuffers.Buffer, ref: FieldRef) u16 {
            return flatbuffers.decodeScalarField(u16, 12, data, ref.offset, 0);
        }

        ///  If the field uses 64-bit offsets.
        pub fn offset64(data: flatbuffers.Buffer, ref: FieldRef) bool {
            return flatbuffers.decodeScalarField(bool, 13, data, ref.offset, false);
        }
    };

    pub const KeyValueRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const KeyValue = struct {
        pub fn key(data: flatbuffers.Buffer, ref: KeyValueRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing KeyValue.key field");
        }

        pub fn value(data: flatbuffers.Buffer, ref: KeyValueRef) ?flatbuffers.String {
            return flatbuffers.decodeStringField(1, data, ref.offset);
        }
    };

    pub const ObjectRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const Object = struct {
        pub fn name(data: flatbuffers.Buffer, ref: ObjectRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing Object.name field");
        }

        pub fn fields(data: flatbuffers.Buffer, ref: ObjectRef) flatbuffers.Vector(reflection.FieldRef) {
            return flatbuffers.decodeVectorField(reflection.FieldRef, 1, data, ref.offset) orelse
                @panic("missing Object.fields field");
        }

        pub fn is_struct(data: flatbuffers.Buffer, ref: ObjectRef) bool {
            return flatbuffers.decodeScalarField(bool, 2, data, ref.offset, false);
        }

        pub fn minalign(data: flatbuffers.Buffer, ref: ObjectRef) i32 {
            return flatbuffers.decodeScalarField(i32, 3, data, ref.offset, 0);
        }

        pub fn bytesize(data: flatbuffers.Buffer, ref: ObjectRef) i32 {
            return flatbuffers.decodeScalarField(i32, 4, data, ref.offset, 0);
        }

        pub fn attributes(data: flatbuffers.Buffer, ref: ObjectRef) ?flatbuffers.Vector(reflection.KeyValueRef) {
            return flatbuffers.decodeVectorField(reflection.KeyValueRef, 5, data, ref.offset);
        }

        ///  Array of documentation comments for the object
        pub fn documentation(data: flatbuffers.Buffer, ref: ObjectRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 6, data, ref.offset);
        }

        ///  File that this Object is declared in.
        pub fn declaration_file(data: flatbuffers.Buffer, ref: ObjectRef) ?flatbuffers.String {
            return flatbuffers.decodeStringField(7, data, ref.offset);
        }
    };

    pub const RPCCallRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const RPCCall = struct {
        pub fn name(data: flatbuffers.Buffer, ref: RPCCallRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing RPCCall.name field");
        }

        pub fn request(data: flatbuffers.Buffer, ref: RPCCallRef) reflection.ObjectRef {
            return flatbuffers.decodeTableField(reflection.ObjectRef, 1, data, ref.offset) orelse
                @panic("missing RPCCall.request field");
        }

        pub fn response(data: flatbuffers.Buffer, ref: RPCCallRef) reflection.ObjectRef {
            return flatbuffers.decodeTableField(reflection.ObjectRef, 2, data, ref.offset) orelse
                @panic("missing RPCCall.response field");
        }

        pub fn attributes(data: flatbuffers.Buffer, ref: RPCCallRef) ?flatbuffers.Vector(reflection.KeyValueRef) {
            return flatbuffers.decodeVectorField(reflection.KeyValueRef, 3, data, ref.offset);
        }

        pub fn documentation(data: flatbuffers.Buffer, ref: RPCCallRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 4, data, ref.offset);
        }
    };

    pub const SchemaRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const Schema = struct {
        pub fn objects(data: flatbuffers.Buffer, ref: SchemaRef) flatbuffers.Vector(reflection.ObjectRef) {
            return flatbuffers.decodeVectorField(reflection.ObjectRef, 0, data, ref.offset) orelse
                @panic("missing Schema.objects field");
        }

        pub fn enums(data: flatbuffers.Buffer, ref: SchemaRef) flatbuffers.Vector(reflection.EnumRef) {
            return flatbuffers.decodeVectorField(reflection.EnumRef, 1, data, ref.offset) orelse
                @panic("missing Schema.enums field");
        }

        pub fn file_ident(data: flatbuffers.Buffer, ref: SchemaRef) ?flatbuffers.String {
            return flatbuffers.decodeStringField(2, data, ref.offset);
        }

        pub fn file_ext(data: flatbuffers.Buffer, ref: SchemaRef) ?flatbuffers.String {
            return flatbuffers.decodeStringField(3, data, ref.offset);
        }

        pub fn root_table(data: flatbuffers.Buffer, ref: SchemaRef) ?reflection.ObjectRef {
            return flatbuffers.decodeTableField(reflection.ObjectRef, 4, data, ref.offset);
        }

        pub fn services(data: flatbuffers.Buffer, ref: SchemaRef) ?flatbuffers.Vector(reflection.ServiceRef) {
            return flatbuffers.decodeVectorField(reflection.ServiceRef, 5, data, ref.offset);
        }

        pub fn advanced_features(data: flatbuffers.Buffer, ref: SchemaRef) reflection.AdvancedFeatures {
            return flatbuffers.decodeBitFlagsField(reflection.AdvancedFeatures, 6, data, ref.offset, reflection.AdvancedFeatures{});
        }

        ///  All the files used in this compilation. Files are relative to where
        ///  flatc was invoked.
        pub fn fbs_files(data: flatbuffers.Buffer, ref: SchemaRef) ?flatbuffers.Vector(reflection.SchemaFileRef) {
            return flatbuffers.decodeVectorField(reflection.SchemaFileRef, 7, data, ref.offset);
        }
    };

    pub const SchemaFileRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const SchemaFile = struct {
        ///  Filename, relative to project root.
        pub fn filename(data: flatbuffers.Buffer, ref: SchemaFileRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing SchemaFile.filename field");
        }

        ///  Names of included files, relative to project root.
        pub fn included_filenames(data: flatbuffers.Buffer, ref: SchemaFileRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 1, data, ref.offset);
        }
    };

    pub const ServiceRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const Service = struct {
        pub fn name(data: flatbuffers.Buffer, ref: ServiceRef) flatbuffers.String {
            return flatbuffers.decodeStringField(0, data, ref.offset) orelse
                @panic("missing Service.name field");
        }

        pub fn calls(data: flatbuffers.Buffer, ref: ServiceRef) ?flatbuffers.Vector(reflection.RPCCallRef) {
            return flatbuffers.decodeVectorField(reflection.RPCCallRef, 1, data, ref.offset);
        }

        pub fn attributes(data: flatbuffers.Buffer, ref: ServiceRef) ?flatbuffers.Vector(reflection.KeyValueRef) {
            return flatbuffers.decodeVectorField(reflection.KeyValueRef, 2, data, ref.offset);
        }

        pub fn documentation(data: flatbuffers.Buffer, ref: ServiceRef) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 3, data, ref.offset);
        }

        ///  File that this Service is declared in.
        pub fn declaration_file(data: flatbuffers.Buffer, ref: ServiceRef) ?flatbuffers.String {
            return flatbuffers.decodeStringField(4, data, ref.offset);
        }
    };

    pub const TypeRef = packed struct {
        pub const kind = flatbuffers.Kind.Table;
        offset: u32,
    };

    pub const Type = struct {
        pub fn base_type(data: flatbuffers.Buffer, ref: TypeRef) reflection.BaseType {
            return flatbuffers.decodeEnumField(reflection.BaseType, 0, data, ref.offset, reflection.BaseType.None);
        }

        pub fn element(data: flatbuffers.Buffer, ref: TypeRef) reflection.BaseType {
            return flatbuffers.decodeEnumField(reflection.BaseType, 1, data, ref.offset, reflection.BaseType.None);
        }

        pub fn index(data: flatbuffers.Buffer, ref: TypeRef) i32 {
            return flatbuffers.decodeScalarField(i32, 2, data, ref.offset, -1);
        }

        pub fn fixed_length(data: flatbuffers.Buffer, ref: TypeRef) u16 {
            return flatbuffers.decodeScalarField(u16, 3, data, ref.offset, 0);
        }

        ///  The size (octets) of the `base_type` field.
        pub fn base_size(data: flatbuffers.Buffer, ref: TypeRef) u32 {
            return flatbuffers.decodeScalarField(u32, 4, data, ref.offset, 4);
        }

        ///  The size (octets) of the `element` field, if present.
        pub fn element_size(data: flatbuffers.Buffer, ref: TypeRef) u32 {
            return flatbuffers.decodeScalarField(u32, 5, data, ref.offset, 0);
        }
    };
};

pub fn decodeRoot(data: flatbuffers.Buffer) reflection.SchemaRef {
    const offset = std.mem.readInt(u32, data[0..4], .little);
    return .{ .offset = offset };
}

pub fn validateRoot(data: flatbuffers.Buffer) !void {
    if (data.len < 8)
        return error.Invalid;

    const root = decodeRoot(data);
    if (root.offset >= data.len)
        return error.Invalid;
}
