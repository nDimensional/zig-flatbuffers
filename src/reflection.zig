const std = @import("std");

const common = @import("common.zig");
const Kind = common.Kind;
const String = common.String;
const Vector = common.Vector;
const Buffer = common.Buffer;

pub const file_identifier = "BFBS";
pub const file_extension = "bfbs";

pub const AdvancedFeatures = packed struct {
    pub const kind = Kind{
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
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Enum = struct {
    pub fn name(data: Buffer, ref: EnumRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing Enum.name field");
    }

    pub fn values(data: Buffer, ref: EnumRef) Vector(EnumValRef) {
        const field_id = 1;
        return common.decodeVectorField(field_id, EnumValRef, data, ref.offset) orelse
            @panic("missing Enum.values field");
    }

    pub fn is_union(data: Buffer, ref: EnumRef) bool {
        const field_id = 2;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }

    pub fn underlying_type(data: Buffer, ref: EnumRef) TypeRef {
        const field_id = 3;
        return common.decodeTableField(field_id, TypeRef, data, ref.offset) orelse
            @panic("missing Enum.underlying_type field");
    }

    pub fn attributes(data: Buffer, ref: EnumRef) ?Vector(KeyValueRef) {
        const field_id = 4;
        return common.decodeVectorField(field_id, KeyValueRef, data, ref.offset);
    }

    ///  Array of documentation comments for the enum
    pub fn documentation(data: Buffer, ref: EnumRef) ?Vector(String) {
        const field_id = 5;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }

    ///  File that this Enum is declared in.
    pub fn declaration_file(data: Buffer, ref: EnumRef) ?String {
        const field_id = 6;
        return common.decodeStringField(field_id, data, ref.offset);
    }
};

pub const EnumValRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const EnumVal = struct {
    pub fn name(data: Buffer, ref: EnumValRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing EnumVal.name field");
    }

    pub fn value(data: Buffer, ref: EnumValRef) i64 {
        const field_id = 1;
        return common.decodeScalarField(field_id, i64, data, ref.offset, 0);
    }

    pub fn union_type(data: Buffer, ref: EnumValRef) ?TypeRef {
        const field_id = 3;
        return common.decodeTableField(field_id, TypeRef, data, ref.offset);
    }

    ///  Array of documentation comments for the enum value
    pub fn documentation(data: Buffer, ref: EnumValRef) ?Vector(String) {
        const field_id = 4;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }

    pub fn attributes(data: Buffer, ref: EnumValRef) ?Vector(KeyValueRef) {
        const field_id = 5;
        return common.decodeVectorField(field_id, KeyValueRef, data, ref.offset);
    }
};

pub const FieldRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Field = struct {
    pub fn name(data: Buffer, ref: FieldRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing Field.name field");
    }

    pub fn @"type"(data: Buffer, ref: FieldRef) TypeRef {
        const field_id = 1;
        return common.decodeTableField(field_id, TypeRef, data, ref.offset) orelse
            @panic("missing Field.type field");
    }

    pub fn id(data: Buffer, ref: FieldRef) u16 {
        const field_id = 2;
        return common.decodeScalarField(field_id, u16, data, ref.offset, 0);
    }

    pub fn offset(data: Buffer, ref: FieldRef) u16 {
        const field_id = 3;
        return common.decodeScalarField(field_id, u16, data, ref.offset, 0);
    }

    pub fn default_integer(data: Buffer, ref: FieldRef) i64 {
        const field_id = 4;
        return common.decodeScalarField(field_id, i64, data, ref.offset, 0);
    }

    pub fn default_real(data: Buffer, ref: FieldRef) f64 {
        const field_id = 5;
        return common.decodeScalarField(field_id, f64, data, ref.offset, 0);
    }

    pub fn deprecated(data: Buffer, ref: FieldRef) bool {
        const field_id = 6;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }

    pub fn required(data: Buffer, ref: FieldRef) bool {
        const field_id = 7;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }

    pub fn key(data: Buffer, ref: FieldRef) bool {
        const field_id = 8;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }

    pub fn attributes(data: Buffer, ref: FieldRef) ?Vector(KeyValueRef) {
        const field_id = 9;
        return common.decodeVectorField(field_id, KeyValueRef, data, ref.offset);
    }

    ///  Array of documentation comments for the field
    pub fn documentation(data: Buffer, ref: FieldRef) ?Vector(String) {
        const field_id = 10;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }

    pub fn optional(data: Buffer, ref: FieldRef) bool {
        const field_id = 11;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }

    ///  Number of padding octets to always add after this field. Structs only.
    pub fn padding(data: Buffer, ref: FieldRef) u16 {
        const field_id = 12;
        return common.decodeScalarField(field_id, u16, data, ref.offset, 0);
    }

    ///  If the field uses 64-bit offsets.
    pub fn offset64(data: Buffer, ref: FieldRef) bool {
        const field_id = 13;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }
};

pub const KeyValueRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const KeyValue = struct {
    pub fn key(data: Buffer, ref: KeyValueRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing KeyValue.key field");
    }

    pub fn value(data: Buffer, ref: KeyValueRef) ?String {
        const field_id = 1;
        return common.decodeStringField(field_id, data, ref.offset);
    }
};

pub const ObjectRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Object = struct {
    pub fn name(data: Buffer, ref: ObjectRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing Object.name field");
    }

    pub fn fields(data: Buffer, ref: ObjectRef) Vector(FieldRef) {
        const field_id = 1;
        return common.decodeVectorField(field_id, FieldRef, data, ref.offset) orelse
            @panic("missing Object.fields field");
    }

    pub fn is_struct(data: Buffer, ref: ObjectRef) bool {
        const field_id = 2;
        return common.decodeScalarField(field_id, bool, data, ref.offset, false);
    }

    pub fn minalign(data: Buffer, ref: ObjectRef) i32 {
        const field_id = 3;
        return common.decodeScalarField(field_id, i32, data, ref.offset, 0);
    }

    pub fn bytesize(data: Buffer, ref: ObjectRef) i32 {
        const field_id = 4;
        return common.decodeScalarField(field_id, i32, data, ref.offset, 0);
    }

    pub fn attributes(data: Buffer, ref: ObjectRef) ?Vector(KeyValueRef) {
        const field_id = 5;
        return common.decodeVectorField(field_id, KeyValueRef, data, ref.offset);
    }

    ///  Array of documentation comments for the object
    pub fn documentation(data: Buffer, ref: ObjectRef) ?Vector(String) {
        const field_id = 6;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }

    ///  File that this Object is declared in.
    pub fn declaration_file(data: Buffer, ref: ObjectRef) ?String {
        const field_id = 7;
        return common.decodeStringField(field_id, data, ref.offset);
    }
};

pub const RPCCallRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const RPCCall = struct {
    pub fn name(data: Buffer, ref: RPCCallRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing RPCCall.name field");
    }

    pub fn request(data: Buffer, ref: RPCCallRef) ObjectRef {
        const field_id = 1;
        return common.decodeTableField(field_id, ObjectRef, data, ref.offset) orelse
            @panic("missing RPCCall.request field");
    }

    pub fn response(data: Buffer, ref: RPCCallRef) ObjectRef {
        const field_id = 2;
        return common.decodeTableField(field_id, ObjectRef, data, ref.offset) orelse
            @panic("missing RPCCall.response field");
    }

    pub fn attributes(data: Buffer, ref: RPCCallRef) ?Vector(KeyValueRef) {
        const field_id = 3;
        return common.decodeVectorField(field_id, KeyValueRef, data, ref.offset);
    }

    pub fn documentation(data: Buffer, ref: RPCCallRef) ?Vector(String) {
        const field_id = 4;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }
};

pub const SchemaRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Schema = struct {
    pub fn objects(data: Buffer, ref: SchemaRef) Vector(ObjectRef) {
        const field_id = 0;
        return common.decodeVectorField(field_id, ObjectRef, data, ref.offset) orelse
            @panic("missing Schema.objects field");
    }

    pub fn enums(data: Buffer, ref: SchemaRef) Vector(EnumRef) {
        const field_id = 1;
        return common.decodeVectorField(field_id, EnumRef, data, ref.offset) orelse
            @panic("missing Schema.enums field");
    }

    pub fn file_ident(data: Buffer, ref: SchemaRef) ?String {
        const field_id = 2;
        return common.decodeStringField(field_id, data, ref.offset);
    }

    pub fn file_ext(data: Buffer, ref: SchemaRef) ?String {
        const field_id = 3;
        return common.decodeStringField(field_id, data, ref.offset);
    }

    pub fn root_table(data: Buffer, ref: SchemaRef) ?ObjectRef {
        const field_id = 4;
        return common.decodeTableField(field_id, ObjectRef, data, ref.offset);
    }

    pub fn services(data: Buffer, ref: SchemaRef) ?Vector(ServiceRef) {
        const field_id = 5;
        return common.decodeVectorField(field_id, ServiceRef, data, ref.offset);
    }

    pub fn advanced_features(data: Buffer, ref: SchemaRef) AdvancedFeatures {
        const field_id = 6;
        return common.decodeBitFlagsField(field_id, AdvancedFeatures, data, ref.offset, AdvancedFeatures{});
    }

    ///  All the files used in this compilation. Files are relative to where
    ///  flatc was invoked.
    pub fn fbs_files(data: Buffer, ref: SchemaRef) ?Vector(SchemaFileRef) {
        const field_id = 7;
        return common.decodeVectorField(field_id, SchemaFileRef, data, ref.offset);
    }
};

pub const SchemaFileRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const SchemaFile = struct {
    ///  Filename, relative to project root.
    pub fn filename(data: Buffer, ref: SchemaFileRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing SchemaFile.filename field");
    }

    ///  Names of included files, relative to project root.
    pub fn included_filenames(data: Buffer, ref: SchemaFileRef) ?Vector(String) {
        const field_id = 1;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }
};

pub const ServiceRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Service = struct {
    pub fn name(data: Buffer, ref: ServiceRef) String {
        const field_id = 0;
        return common.decodeStringField(field_id, data, ref.offset) orelse
            @panic("missing Service.name field");
    }

    pub fn calls(data: Buffer, ref: ServiceRef) ?Vector(RPCCallRef) {
        const field_id = 1;
        return common.decodeVectorField(field_id, RPCCallRef, data, ref.offset);
    }

    pub fn attributes(data: Buffer, ref: ServiceRef) ?Vector(KeyValueRef) {
        const field_id = 2;
        return common.decodeVectorField(field_id, KeyValueRef, data, ref.offset);
    }

    pub fn documentation(data: Buffer, ref: ServiceRef) ?Vector(String) {
        const field_id = 3;
        return common.decodeVectorField(field_id, String, data, ref.offset);
    }

    ///  File that this Service is declared in.
    pub fn declaration_file(data: Buffer, ref: ServiceRef) ?String {
        const field_id = 4;
        return common.decodeStringField(field_id, data, ref.offset);
    }
};

pub const TypeRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Type = struct {
    pub fn base_type(data: Buffer, ref: TypeRef) BaseType {
        const field_id = 0;
        return common.decodeEnumField(field_id, BaseType, data, ref.offset, BaseType.None);
    }

    pub fn element(data: Buffer, ref: TypeRef) BaseType {
        const field_id = 1;
        return common.decodeEnumField(field_id, BaseType, data, ref.offset, BaseType.None);
    }

    pub fn index(data: Buffer, ref: TypeRef) i32 {
        const field_id = 2;
        return common.decodeScalarField(field_id, i32, data, ref.offset, -1);
    }

    pub fn fixed_length(data: Buffer, ref: TypeRef) u16 {
        const field_id = 3;
        return common.decodeScalarField(field_id, u16, data, ref.offset, 0);
    }

    ///  The size (octets) of the `base_type` field.
    pub fn base_size(data: Buffer, ref: TypeRef) u32 {
        const field_id = 4;
        return common.decodeScalarField(field_id, u32, data, ref.offset, 4);
    }

    ///  The size (octets) of the `element` field, if present.
    pub fn element_size(data: Buffer, ref: TypeRef) u32 {
        const field_id = 5;
        return common.decodeScalarField(field_id, u32, data, ref.offset, 0);
    }
};

pub fn decodeRoot(data: Buffer) SchemaRef {
    const offset = std.mem.readInt(u32, data[0..4], .little);
    return .{ .offset = offset };
}
