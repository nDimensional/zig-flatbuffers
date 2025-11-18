const std = @import("std");

const flatbuffers = @import("flatbuffers.zig");

pub const file_identifier = "BFBS";
pub const file_extension = "bfbs";

pub const reflection = struct {
    pub const AdvancedFeatures = packed struct {
        pub const @"#kind" = flatbuffers.Kind{
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

    pub const Enum = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn name(@"#self": Enum) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing Enum.name field");
        }

        pub fn values(@"#self": Enum) flatbuffers.Vector(reflection.EnumVal) {
            return flatbuffers.decodeVectorField(reflection.EnumVal, 1, @"#self".@"#ref") orelse
                @panic("missing Enum.values field");
        }

        pub fn is_union(@"#self": Enum) bool {
            return flatbuffers.decodeScalarField(bool, 2, @"#self".@"#ref", false);
        }

        pub fn underlying_type(@"#self": Enum) reflection.Type {
            return flatbuffers.decodeTableField(reflection.Type, 3, @"#self".@"#ref") orelse
                @panic("missing Enum.underlying_type field");
        }

        pub fn attributes(@"#self": Enum) ?flatbuffers.Vector(reflection.KeyValue) {
            return flatbuffers.decodeVectorField(reflection.KeyValue, 4, @"#self".@"#ref");
        }

        ///  Array of documentation comments for the enum
        pub fn documentation(@"#self": Enum) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 5, @"#self".@"#ref");
        }

        ///  File that this Enum is declared in.
        pub fn declaration_file(@"#self": Enum) ?flatbuffers.String {
            return flatbuffers.decodeStringField(6, @"#self".@"#ref");
        }
    };

    pub const EnumVal = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn name(@"#self": EnumVal) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing EnumVal.name field");
        }

        pub fn value(@"#self": EnumVal) i64 {
            return flatbuffers.decodeScalarField(i64, 1, @"#self".@"#ref", 0);
        }

        pub fn union_type(@"#self": EnumVal) ?reflection.Type {
            return flatbuffers.decodeTableField(reflection.Type, 3, @"#self".@"#ref");
        }

        ///  Array of documentation comments for the enum value
        pub fn documentation(@"#self": EnumVal) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 4, @"#self".@"#ref");
        }

        pub fn attributes(@"#self": EnumVal) ?flatbuffers.Vector(reflection.KeyValue) {
            return flatbuffers.decodeVectorField(reflection.KeyValue, 5, @"#self".@"#ref");
        }
    };

    pub const Field = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn name(@"#self": Field) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing Field.name field");
        }

        pub fn @"type"(@"#self": Field) reflection.Type {
            return flatbuffers.decodeTableField(reflection.Type, 1, @"#self".@"#ref") orelse
                @panic("missing Field.type field");
        }

        pub fn id(@"#self": Field) u16 {
            return flatbuffers.decodeScalarField(u16, 2, @"#self".@"#ref", 0);
        }

        pub fn offset(@"#self": Field) u16 {
            return flatbuffers.decodeScalarField(u16, 3, @"#self".@"#ref", 0);
        }

        pub fn default_integer(@"#self": Field) i64 {
            return flatbuffers.decodeScalarField(i64, 4, @"#self".@"#ref", 0);
        }

        pub fn default_real(@"#self": Field) f64 {
            return flatbuffers.decodeScalarField(f64, 5, @"#self".@"#ref", 0);
        }

        pub fn deprecated(@"#self": Field) bool {
            return flatbuffers.decodeScalarField(bool, 6, @"#self".@"#ref", false);
        }

        pub fn required(@"#self": Field) bool {
            return flatbuffers.decodeScalarField(bool, 7, @"#self".@"#ref", false);
        }

        pub fn key(@"#self": Field) bool {
            return flatbuffers.decodeScalarField(bool, 8, @"#self".@"#ref", false);
        }

        pub fn attributes(@"#self": Field) ?flatbuffers.Vector(reflection.KeyValue) {
            return flatbuffers.decodeVectorField(reflection.KeyValue, 9, @"#self".@"#ref");
        }

        ///  Array of documentation comments for the field
        pub fn documentation(@"#self": Field) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 10, @"#self".@"#ref");
        }

        pub fn optional(@"#self": Field) bool {
            return flatbuffers.decodeScalarField(bool, 11, @"#self".@"#ref", false);
        }

        ///  Number of padding octets to always add after this field. Structs only.
        pub fn padding(@"#self": Field) u16 {
            return flatbuffers.decodeScalarField(u16, 12, @"#self".@"#ref", 0);
        }

        ///  If the field uses 64-bit offsets.
        pub fn offset64(@"#self": Field) bool {
            return flatbuffers.decodeScalarField(bool, 13, @"#self".@"#ref", false);
        }
    };

    pub const KeyValue = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn key(@"#self": KeyValue) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing KeyValue.key field");
        }

        pub fn value(@"#self": KeyValue) ?flatbuffers.String {
            return flatbuffers.decodeStringField(1, @"#self".@"#ref");
        }
    };

    pub const Object = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn name(@"#self": Object) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing Object.name field");
        }

        pub fn fields(@"#self": Object) flatbuffers.Vector(reflection.Field) {
            return flatbuffers.decodeVectorField(reflection.Field, 1, @"#self".@"#ref") orelse
                @panic("missing Object.fields field");
        }

        pub fn is_struct(@"#self": Object) bool {
            return flatbuffers.decodeScalarField(bool, 2, @"#self".@"#ref", false);
        }

        pub fn minalign(@"#self": Object) i32 {
            return flatbuffers.decodeScalarField(i32, 3, @"#self".@"#ref", 0);
        }

        pub fn bytesize(@"#self": Object) i32 {
            return flatbuffers.decodeScalarField(i32, 4, @"#self".@"#ref", 0);
        }

        pub fn attributes(@"#self": Object) ?flatbuffers.Vector(reflection.KeyValue) {
            return flatbuffers.decodeVectorField(reflection.KeyValue, 5, @"#self".@"#ref");
        }

        ///  Array of documentation comments for the object
        pub fn documentation(@"#self": Object) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 6, @"#self".@"#ref");
        }

        ///  File that this Object is declared in.
        pub fn declaration_file(@"#self": Object) ?flatbuffers.String {
            return flatbuffers.decodeStringField(7, @"#self".@"#ref");
        }
    };

    pub const RPCCall = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn name(@"#self": RPCCall) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing RPCCall.name field");
        }

        pub fn request(@"#self": RPCCall) reflection.Object {
            return flatbuffers.decodeTableField(reflection.Object, 1, @"#self".@"#ref") orelse
                @panic("missing RPCCall.request field");
        }

        pub fn response(@"#self": RPCCall) reflection.Object {
            return flatbuffers.decodeTableField(reflection.Object, 2, @"#self".@"#ref") orelse
                @panic("missing RPCCall.response field");
        }

        pub fn attributes(@"#self": RPCCall) ?flatbuffers.Vector(reflection.KeyValue) {
            return flatbuffers.decodeVectorField(reflection.KeyValue, 3, @"#self".@"#ref");
        }

        pub fn documentation(@"#self": RPCCall) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 4, @"#self".@"#ref");
        }
    };

    pub const Schema = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn objects(@"#self": Schema) flatbuffers.Vector(reflection.Object) {
            return flatbuffers.decodeVectorField(reflection.Object, 0, @"#self".@"#ref") orelse
                @panic("missing Schema.objects field");
        }

        pub fn enums(@"#self": Schema) flatbuffers.Vector(reflection.Enum) {
            return flatbuffers.decodeVectorField(reflection.Enum, 1, @"#self".@"#ref") orelse
                @panic("missing Schema.enums field");
        }

        pub fn file_ident(@"#self": Schema) ?flatbuffers.String {
            return flatbuffers.decodeStringField(2, @"#self".@"#ref");
        }

        pub fn file_ext(@"#self": Schema) ?flatbuffers.String {
            return flatbuffers.decodeStringField(3, @"#self".@"#ref");
        }

        pub fn root_table(@"#self": Schema) ?reflection.Object {
            return flatbuffers.decodeTableField(reflection.Object, 4, @"#self".@"#ref");
        }

        pub fn services(@"#self": Schema) ?flatbuffers.Vector(reflection.Service) {
            return flatbuffers.decodeVectorField(reflection.Service, 5, @"#self".@"#ref");
        }

        pub fn advanced_features(@"#self": Schema) reflection.AdvancedFeatures {
            return flatbuffers.decodeBitFlagsField(reflection.AdvancedFeatures, 6, @"#self".@"#ref", reflection.AdvancedFeatures{});
        }

        ///  All the files used in this compilation. Files are relative to where
        ///  flatc was invoked.
        pub fn fbs_files(@"#self": Schema) ?flatbuffers.Vector(reflection.SchemaFile) {
            return flatbuffers.decodeVectorField(reflection.SchemaFile, 7, @"#self".@"#ref");
        }
    };

    pub const SchemaFile = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        ///  Filename, relative to project root.
        pub fn filename(@"#self": SchemaFile) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing SchemaFile.filename field");
        }

        ///  Names of included files, relative to project root.
        pub fn included_filenames(@"#self": SchemaFile) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 1, @"#self".@"#ref");
        }
    };

    pub const Service = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn name(@"#self": Service) flatbuffers.String {
            return flatbuffers.decodeStringField(0, @"#self".@"#ref") orelse
                @panic("missing Service.name field");
        }

        pub fn calls(@"#self": Service) ?flatbuffers.Vector(reflection.RPCCall) {
            return flatbuffers.decodeVectorField(reflection.RPCCall, 1, @"#self".@"#ref");
        }

        pub fn attributes(@"#self": Service) ?flatbuffers.Vector(reflection.KeyValue) {
            return flatbuffers.decodeVectorField(reflection.KeyValue, 2, @"#self".@"#ref");
        }

        pub fn documentation(@"#self": Service) ?flatbuffers.Vector(flatbuffers.String) {
            return flatbuffers.decodeVectorField(flatbuffers.String, 3, @"#self".@"#ref");
        }

        ///  File that this Service is declared in.
        pub fn declaration_file(@"#self": Service) ?flatbuffers.String {
            return flatbuffers.decodeStringField(4, @"#self".@"#ref");
        }
    };

    pub const Type = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        @"#ref": flatbuffers.Ref,

        pub fn base_type(@"#self": Type) reflection.BaseType {
            return flatbuffers.decodeEnumField(reflection.BaseType, 0, @"#self".@"#ref", reflection.BaseType.None);
        }

        pub fn element(@"#self": Type) reflection.BaseType {
            return flatbuffers.decodeEnumField(reflection.BaseType, 1, @"#self".@"#ref", reflection.BaseType.None);
        }

        pub fn index(@"#self": Type) i32 {
            return flatbuffers.decodeScalarField(i32, 2, @"#self".@"#ref", -1);
        }

        pub fn fixed_length(@"#self": Type) u16 {
            return flatbuffers.decodeScalarField(u16, 3, @"#self".@"#ref", 0);
        }

        ///  The size (octets) of the `base_type` field.
        pub fn base_size(@"#self": Type) u32 {
            return flatbuffers.decodeScalarField(u32, 4, @"#self".@"#ref", 4);
        }

        ///  The size (octets) of the `element` field, if present.
        pub fn element_size(@"#self": Type) u32 {
            return flatbuffers.decodeScalarField(u32, 5, @"#self".@"#ref", 0);
        }
    };
};

pub fn decodeRoot(data: []align(8) const u8) reflection.Schema {
    const start = flatbuffers.Ref{
        .ptr = data.ptr,
        .len = @truncate(data.len),
        .offset = 0,
    };

    return .{ .@"#ref" = start.uoffset() };
}

pub fn validateRoot(data: []align(8) const u8) !void {
    if (data.len < 8)
        return error.Invalid;

    const root = decodeRoot(data);
    if (root.offset >= data.len)
        return error.Invalid;
}
