const std = @import("std");

// This schema defines objects that represent a parsed schema, like
// the binary version of a .fbs file.
// This could be used to operate on unknown FlatBuffers at runtime.
// It can even ... represent itself (!)

pub const namespace = "reflection";

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

pub const Type = struct {
    base_type: BaseType = .None,

    element: BaseType = .None, // Only if base_type == Vector or base_type == Array.

    /// If base_type == Object, index into "objects" below.
    /// If base_type == Union, UnionType, or integral derived
    /// from an enum, index into "enums" below.
    /// If base_type == Vector && element == Union or UnionType.
    index: i32 = -1,

    fixed_length: u16 = 0, // Only if base_type == Array.

    /// The size (octets) of the `base_type` field.
    base_size: u32 = 4, // 4 Is a common size due to offsets being that size.

    /// The size (octets) of the `element` field, if present.
    element_size: u32 = 0,
};

pub const KeyValue = struct {
    key: []const u8,
    value: ?[]const u8 = null,
};

pub const EnumVal = struct {
    name: []const u8,
    value: i64,
    object: ?*const Object = null,
    union_type: ?*const Type = null,
    documentation: ?[]const []const u8 = null,
    attributes: ?[]const *const KeyValue = null,
};

pub const Enum = struct {
    name: []const u8,
    values: []const *const EnumVal, // In order of their values.
    is_union: bool = false,
    underlying_type: Type,
    attributes: ?[]const *const KeyValue = null,
    documentation: ?[]const []const u8 = null,
    /// File that this Enum is declared in.
    declaration_file: ?[]const u8 = null,
};

pub const Field = struct {
    name: []const u8,
    type: Type,
    id: u16,
    offset: u16,
    default_integer: i64 = 0,
    default_real: f64 = 0.0,
    deprecated: bool = false,
    required: bool = false,
    key: bool = false,
    attributes: ?[]const *KeyValue = null,
    documentation: ?[]const []const u8 = null,
    optional: bool = false,
    /// Number of padding octets to always add after this field. Structs only.
    padding: u16 = 0,
    /// If the field uses 64-bit offsets.
    offset64: bool = false,
};

pub const Object = struct { // Used for both tables and structs.
    name: []const u8,
    fields: []const *Field, // Sorted.
    is_struct: bool = false,
    minalign: i32,
    bytesize: i32, // For structs.
    attributes: ?[]const *const KeyValue = null,
    documentation: ?[]const []const u8 = null,
    /// File that this Object is declared in.
    declaration_file: ?[]const u8 = null,
};

pub const RPCCall = struct {
    name: []const u8,
    request: *const Object, // must be a table (not a struct)
    response: *const Object, // must be a table (not a struct)
    attributes: ?[]const *const KeyValue = null,
    documentation: ?[]const []const u8 = null,
};

pub const Service = struct {
    name: []const u8,
    calls: ?[]const *const RPCCall = null,
    attributes: ?[]const *const KeyValue = null,
    documentation: ?[]const []const u8 = null,
    /// File that this Service is declared in.
    declaration_file: ?[]const u8 = null,
};

/// New schema language features that are not supported by old code generators.
pub const AdvancedFeatures = packed struct(u64) {
    AdvancedArrayFeatures: bool = false,
    AdvancedUnionFeatures: bool = false,
    OptionalScalars: bool = false,
    DefaultVectorsAndStrings: bool = false,
    _: u60 = 0, // padding
};

/// File specific information.
/// Symbols declared within a file may be recovered by iterating over all
/// symbols and examining the `declaration_file` field.
pub const SchemaFile = struct {
    /// Filename, relative to project root.
    filename: []const u8,
    /// Names of included files, relative to project root.
    included_filenames: ?[]const []const u8 = null,
};

pub const Schema = struct {
    objects: []const *const Object, // Sorted.
    enums: []const *const Enum, // Sorted.
    file_ident: ?[]const u8 = null,
    file_ext: ?[]const u8 = null,
    root_table: ?*const Object = null,
    services: ?[]const *const Service = null, // Sorted.
    advanced_features: AdvancedFeatures = .{},
    /// All the files used in this compilation.
    /// Files are relative to where flatc was invoked.
    fbs_files: ?[]const *const SchemaFile = null, // Sorted.
};

pub const root_type = Schema;

pub const file_identifier = "BFBS";
pub const file_extension = "bfbs";
