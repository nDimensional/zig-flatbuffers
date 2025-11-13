const std = @import("std");

const common = @import("common.zig");
const Kind = common.Kind;
const String = common.String;
const Vector = common.Vector;

pub const file_identifier = "BFBS";
pub const file_extension = "bfbs";

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
    Obj = 15, // Used for tables & structs.
    Union = 16,
    Array = 17,
    Vector64 = 18,

    // Add any new type above this value.
    MaxBaseType = 19,
};

pub const TypeRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Type = struct {
    pub fn base_type(data: []const u8, ref: TypeRef) !BaseType {
        return try common.decodeEnumField(0, BaseType, data, ref.offset, null);
    }

    pub fn element(data: []const u8, ref: TypeRef) !BaseType {
        return try common.decodeEnumField(1, BaseType, data, ref.offset, BaseType.None);
    }

    pub fn index(data: []const u8, ref: TypeRef) i32 {
        return common.decodeScalarField(2, i32, data, ref.offset, -1);
    }

    pub fn fixed_length(data: []const u8, ref: TypeRef) u16 {
        return common.decodeScalarField(3, u16, data, ref.offset, 0);
    }

    pub fn base_size(data: []const u8, ref: TypeRef) u32 {
        return common.decodeScalarField(4, u32, data, ref.offset, 4);
    }

    pub fn element_size(data: []const u8, ref: TypeRef) u32 {
        return common.decodeScalarField(5, u32, data, ref.offset, 0);
    }
};

pub const KeyValueRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const KeyValue = struct {
    pub fn key(data: []const u8, ref: KeyValueRef) ![:0]const u8 {
        return common.decodeStringField(0, data, ref.offset) orelse error.Required;
    }

    pub fn value(data: []const u8, ref: KeyValueRef) ?[:0]const u8 {
        return common.decodeStringField(1, data, ref.offset);
    }
};

pub const EnumValRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const EnumVal = struct {
    pub fn name(data: []const u8, ref: EnumValRef) !String {
        return common.decodeStringField(0, data, ref.offset) orelse error.Required;
    }

    pub fn value(data: []const u8, ref: EnumValRef) i64 {
        return common.decodeScalarField(1, i64, data, ref.offset, null);
    }

    pub fn object(data: []const u8, ref: EnumValRef) ?ObjectRef {
        return common.decodeTableField(3, ObjectRef, data, ref.offset);
    }

    pub fn documentation(data: []const u8, ref: EnumValRef) ?Vector(String) {
        return common.decodeVectorField(5, String, data, ref.offset);
    }
};

pub const EnumRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Enum = struct {
    pub fn name(data: []const u8, ref: EnumRef) !String {
        return common.decodeStringField(0, data, ref.offset) orelse error.Required;
    }

    pub fn values(data: []const u8, ref: EnumRef) !Vector(EnumValRef) {
        return common.decodeVectorField(1, EnumValRef, data, ref.offset) orelse
            error.Required;
    }

    pub fn underlying_type(data: []const u8, ref: EnumRef) !TypeRef {
        return common.decodeTableField(3, TypeRef, data, ref.offset) orelse error.Required;
    }

    pub fn attributes(data: []const u8, ref: EnumRef) ?Vector(KeyValueRef) {
        return common.decodeVectorField(4, KeyValueRef, data, ref.offset);
    }
};

pub const FieldRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Field = struct {
    pub fn name(data: []const u8, ref: FieldRef) !String {
        return common.decodeStringField(0, data, ref.offset) orelse error.Required;
    }

    pub fn @"type"(data: []const u8, ref: FieldRef) !TypeRef {
        return common.decodeTableField(1, TypeRef, data, ref.offset) orelse error.Required;
    }

    pub fn id(data: []const u8, ref: FieldRef) u16 {
        return common.decodeScalarField(2, u16, data, ref.offset, null);
    }

    pub fn default_integer(data: []const u8, ref: FieldRef) i64 {
        return common.decodeScalarField(4, i64, data, ref.offset, 0);
    }

    pub fn default_real(data: []const u8, ref: FieldRef) f64 {
        return common.decodeScalarField(5, f64, data, ref.offset, 0.0);
    }

    pub fn deprecated(data: []const u8, ref: FieldRef) bool {
        return common.decodeScalarField(6, bool, data, ref.offset, false);
    }

    pub fn required(data: []const u8, ref: FieldRef) bool {
        return common.decodeScalarField(7, bool, data, ref.offset, false);
    }

    pub fn key(data: []const u8, ref: FieldRef) bool {
        return common.decodeScalarField(8, bool, data, ref.offset, false);
    }

    pub fn attributes(data: []const u8, ref: FieldRef) ?Vector(KeyValueRef) {
        return common.decodeVectorField(9, KeyValueRef, data, ref.offset);
    }
};

pub const ObjectRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Object = struct {
    pub fn name(data: []const u8, ref: ObjectRef) !String {
        return common.decodeStringField(0, data, ref.offset) orelse error.Required;
    }

    pub fn fields(data: []const u8, ref: ObjectRef) !Vector(FieldRef) {
        return common.decodeVectorField(1, FieldRef, data, ref.offset) orelse error.Required;
    }

    pub fn is_struct(data: []const u8, ref: ObjectRef) bool {
        return common.decodeScalarField(2, bool, data, ref.offset, false);
    }

    pub fn attributes(data: []const u8, ref: ObjectRef) ?Vector(KeyValueRef) {
        return common.decodeVectorField(5, KeyValueRef, data, ref.offset);
    }
};

pub const SchemaRef = packed struct {
    pub const kind = Kind.Table;
    offset: u32,
};

pub const Schema = struct {
    pub fn objects(data: []const u8, ref: SchemaRef) !Vector(ObjectRef) {
        return common.decodeVectorField(0, ObjectRef, data, ref.offset) orelse error.Required;
    }

    pub fn enums(data: []const u8, ref: SchemaRef) !Vector(EnumRef) {
        return common.decodeVectorField(1, EnumRef, data, ref.offset) orelse error.Required;
    }

    pub fn file_ident(data: []const u8, ref: SchemaRef) ?String {
        return common.decodeStringField(2, data, ref.offset);
    }

    pub fn file_ext(data: []const u8, ref: SchemaRef) ?String {
        return common.decodeStringField(3, data, ref.offset);
    }

    pub fn root_table(data: []const u8, ref: SchemaRef) ?ObjectRef {
        return common.decodeTableField(4, ObjectRef, data, ref.offset);
    }
};

pub fn decodeRoot(data: []const u8) SchemaRef {
    const offset = std.mem.readInt(u32, data[0..4], .little);
    return .{ .offset = offset };
}
