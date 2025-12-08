const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("arrow.zon");

pub const org = struct {
    pub const apache = struct {
        pub const arrow = struct {
            pub const flatbuf = struct {
                /// Provided for forward compatibility in case we need to support different
                /// strategies for compressing the IPC message body (like whole-body
                /// compression rather than buffer-level) in the future
                pub const BodyCompressionMethod = enum(i8) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[0];

                    /// Each constituent buffer is first compressed with the indicated
                    /// compressor, and then written with the uncompressed length in the first 8
                    /// bytes as a 64-bit little-endian signed integer followed by the compressed
                    /// buffer bytes (and then padding as required by the protocol). The
                    /// uncompressed length may be set to -1 to indicate that the data that
                    /// follows is not compressed, which can be useful for cases where
                    /// compression does not yield appreciable savings.
                    BUFFER = 0,
                };

                pub const CompressionType = enum(i8) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[1];

                    LZ4_FRAME = 0,
                    ZSTD = 1,
                };

                pub const DateUnit = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[2];

                    DAY = 0,
                    MILLISECOND = 1,
                };

                /// ----------------------------------------------------------------------
                /// Dictionary encoding metadata
                /// Maintained for forwards compatibility, in the future
                /// Dictionaries might be explicit maps between integers and values
                /// allowing for non-contiguous index values
                pub const DictionaryKind = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[3];

                    DenseArray = 0,
                };

                /// ----------------------------------------------------------------------
                /// Endianness of the platform producing the data
                pub const Endianness = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[4];

                    Little = 0,
                    Big = 1,
                };

                /// Represents Arrow Features that might not have full support
                /// within implementations. This is intended to be used in
                /// two scenarios:
                ///  1.  A mechanism for readers of Arrow Streams
                ///      and files to understand that the stream or file makes
                ///      use of a feature that isn't supported or unknown to
                ///      the implementation (and therefore can meet the Arrow
                ///      forward compatibility guarantees).
                ///  2.  A means of negotiating between a client and server
                ///      what features a stream is allowed to use. The enums
                ///      values here are intended to represent higher level
                ///      features, additional details may be negotiated
                ///      with key-value pairs specific to the protocol.
                ///
                /// Enums added to this list should be assigned power-of-two values
                /// to facilitate exchanging and comparing bitmaps for supported
                /// features.
                pub const Feature = enum(i64) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[5];

                    /// Needed to make flatbuffers happy.
                    UNUSED = 0,
                    /// The stream makes use of multiple full dictionaries with the
                    /// same ID and assumes clients implement dictionary replacement
                    /// correctly.
                    DICTIONARY_REPLACEMENT = 1,
                    /// The stream makes use of compressed bodies as described
                    /// in Message.fbs.
                    COMPRESSED_BODY = 2,
                };

                pub const IntervalUnit = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[6];

                    YEAR_MONTH = 0,
                    DAY_TIME = 1,
                    MONTH_DAY_NANO = 2,
                };

                pub const MetadataVersion = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[7];

                    /// 0.1.0 (October 2016).
                    V1 = 0,
                    /// 0.2.0 (February 2017). Non-backwards compatible with V1.
                    V2 = 1,
                    /// 0.3.0 -> 0.7.1 (May - December 2017). Non-backwards compatible with V2.
                    V3 = 2,
                    /// >= 0.8.0 (December 2017). Non-backwards compatible with V3.
                    V4 = 3,
                    /// >= 1.0.0 (July 2020). Backwards compatible with V4 (V5 readers can read V4
                    /// metadata and IPC messages). Implementations are recommended to provide a
                    /// V4 compatibility mode with V5 format changes disabled.
                    ///
                    /// Incompatible changes between V4 and V5:
                    /// - Union buffer layout has changed. In V5, Unions don't have a validity
                    ///   bitmap buffer.
                    V5 = 4,
                };

                pub const Precision = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[8];

                    HALF = 0,
                    SINGLE = 1,
                    DOUBLE = 2,
                };

                pub const SparseMatrixCompressedAxis = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[9];

                    Row = 0,
                    Column = 1,
                };

                pub const TimeUnit = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[10];

                    SECOND = 0,
                    MILLISECOND = 1,
                    MICROSECOND = 2,
                    NANOSECOND = 3,
                };

                pub const UnionMode = enum(i16) {
                    pub const @"#kind" = flatbuffers.Kind.Enum;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".enums[11];

                    Sparse = 0,
                    Dense = 1,
                };

                pub const Block = struct {
                    pub const @"#kind" = flatbuffers.Kind.Struct;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".structs[0];
                    /// Length of the data (this is aligned so there can be a gap between this and
                    /// the metadata).
                    bodyLength: i64,
                    /// Length of the metadata
                    metaDataLength: i32,
                    /// Index to the start of the RecordBlock (note this is past the Message header)
                    offset: i64,
                };

                /// ----------------------------------------------------------------------
                /// A Buffer represents a single contiguous memory segment
                pub const Buffer = struct {
                    pub const @"#kind" = flatbuffers.Kind.Struct;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".structs[1];
                    /// The absolute length (in bytes) of the memory buffer. The memory is found
                    /// from offset (inclusive) to offset + length (non-inclusive). When building
                    /// messages using the encapsulated IPC message, padding bytes may be written
                    /// after a buffer, but such padding bytes do not need to be accounted for in
                    /// the size here.
                    length: i64,
                    /// The relative offset into the shared memory page where the bytes for this
                    /// buffer starts
                    offset: i64,
                };

                /// ----------------------------------------------------------------------
                /// Data structures for describing a table row batch (a collection of
                /// equal-length Arrow arrays)
                /// Metadata about a field at some level of a nested type tree (but not
                /// its children).
                ///
                /// For example, a List<Int16> with values `[[1, 2, 3], null, [4], [5, 6], null]`
                /// would have {length: 5, null_count: 2} for its List node, and {length: 6,
                /// null_count: 0} for its Int16 node, as separate FieldNode structs
                pub const FieldNode = struct {
                    pub const @"#kind" = flatbuffers.Kind.Struct;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".structs[2];
                    /// The number of value slots in the Arrow array at this level of a nested
                    /// tree
                    length: i64,
                    /// The number of observed nulls. Fields with null_count == 0 may choose not
                    /// to write their physical validity bitmap out as a materialized buffer,
                    /// instead setting the length of the bitmap buffer to 0.
                    null_count: i64,
                };

                /// ----------------------------------------------------------------------
                /// The root Message type
                /// This union enables us to easily send different message types without
                /// redundant storage, and in the future we can easily add new message types.
                ///
                /// Arrow implementations do not need to implement all of the message types,
                /// which may include experimental metadata types. For maximum compatibility,
                /// it is best to send data using RecordBatch
                pub const MessageHeader = union(enum(u8)) {
                    pub const @"#kind" = flatbuffers.Kind.Union;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".unions[0];

                    NONE: void = 0,
                    Schema: org.apache.arrow.flatbuf.Schema = 1,
                    DictionaryBatch: org.apache.arrow.flatbuf.DictionaryBatch = 2,
                    RecordBatch: org.apache.arrow.flatbuf.RecordBatch = 3,
                    Tensor: org.apache.arrow.flatbuf.Tensor = 4,
                    SparseTensor: org.apache.arrow.flatbuf.SparseTensor = 5,
                };

                pub const SparseTensorIndex = union(enum(u8)) {
                    pub const @"#kind" = flatbuffers.Kind.Union;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".unions[1];

                    NONE: void = 0,
                    SparseTensorIndexCOO: org.apache.arrow.flatbuf.SparseTensorIndexCOO = 1,
                    SparseMatrixIndexCSX: org.apache.arrow.flatbuf.SparseMatrixIndexCSX = 2,
                    SparseTensorIndexCSF: org.apache.arrow.flatbuf.SparseTensorIndexCSF = 3,
                };

                /// ----------------------------------------------------------------------
                /// Top-level Type value, enabling extensible type-specific metadata. We can
                /// add new logical types to Type without breaking backwards compatibility
                pub const Type = union(enum(u8)) {
                    pub const @"#kind" = flatbuffers.Kind.Union;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".unions[2];

                    NONE: void = 0,
                    Null: org.apache.arrow.flatbuf.Null = 1,
                    Int: org.apache.arrow.flatbuf.Int = 2,
                    FloatingPoint: org.apache.arrow.flatbuf.FloatingPoint = 3,
                    Binary: org.apache.arrow.flatbuf.Binary = 4,
                    Utf8: org.apache.arrow.flatbuf.Utf8 = 5,
                    Bool: org.apache.arrow.flatbuf.Bool = 6,
                    Decimal: org.apache.arrow.flatbuf.Decimal = 7,
                    Date: org.apache.arrow.flatbuf.Date = 8,
                    Time: org.apache.arrow.flatbuf.Time = 9,
                    Timestamp: org.apache.arrow.flatbuf.Timestamp = 10,
                    Interval: org.apache.arrow.flatbuf.Interval = 11,
                    List: org.apache.arrow.flatbuf.List = 12,
                    Struct_: org.apache.arrow.flatbuf.Struct_ = 13,
                    Union: org.apache.arrow.flatbuf.Union = 14,
                    FixedSizeBinary: org.apache.arrow.flatbuf.FixedSizeBinary = 15,
                    FixedSizeList: org.apache.arrow.flatbuf.FixedSizeList = 16,
                    Map: org.apache.arrow.flatbuf.Map = 17,
                    Duration: org.apache.arrow.flatbuf.Duration = 18,
                    LargeBinary: org.apache.arrow.flatbuf.LargeBinary = 19,
                    LargeUtf8: org.apache.arrow.flatbuf.LargeUtf8 = 20,
                    LargeList: org.apache.arrow.flatbuf.LargeList = 21,
                    RunEndEncoded: org.apache.arrow.flatbuf.RunEndEncoded = 22,
                    BinaryView: org.apache.arrow.flatbuf.BinaryView = 23,
                    Utf8View: org.apache.arrow.flatbuf.Utf8View = 24,
                    ListView: org.apache.arrow.flatbuf.ListView = 25,
                    LargeListView: org.apache.arrow.flatbuf.LargeListView = 26,
                };

                /// Opaque binary data
                pub const Binary = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[0];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Logically the same as Binary, but the internal representation uses a view
                /// struct that contains the string length and either the string's entire data
                /// inline (for small strings) or an inlined prefix, an index of another buffer,
                /// and an offset pointing to a slice in that buffer (for non-small strings).
                ///
                /// Since it uses a variable number of data buffers, each Field with this type
                /// must have a corresponding entry in `variadicBufferCounts`.
                pub const BinaryView = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[1];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Optional compression for the memory buffers constituting IPC message
                /// bodies. Intended for use with RecordBatch but could be used for other
                /// message types
                pub const BodyCompression = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[2];
                    pub const @"#constructor" = struct {
                        codec: org.apache.arrow.flatbuf.CompressionType = @enumFromInt(0),
                        method: org.apache.arrow.flatbuf.BodyCompressionMethod = @enumFromInt(0),
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Compressor library.
                    /// For LZ4_FRAME, each compressed buffer must consist of a single frame.
                    pub fn codec(@"#self": BodyCompression) org.apache.arrow.flatbuf.CompressionType {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.CompressionType, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    /// Indicates the way the record batch body was compressed
                    pub fn method(@"#self": BodyCompression) org.apache.arrow.flatbuf.BodyCompressionMethod {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.BodyCompressionMethod, 1, @"#self".@"#ref", @enumFromInt(0));
                    }
                };

                pub const Bool = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[3];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Date is either a 32-bit or 64-bit signed integer type representing an
                /// elapsed time since UNIX epoch (1970-01-01), stored in either of two units:
                ///
                /// * Milliseconds (64 bits) indicating UNIX time elapsed since the epoch (no
                ///   leap seconds), where the values are evenly divisible by 86400000
                /// * Days (32 bits) since the UNIX epoch
                pub const Date = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[4];
                    pub const @"#constructor" = struct {
                        unit: org.apache.arrow.flatbuf.DateUnit = @enumFromInt(1),
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn unit(@"#self": Date) org.apache.arrow.flatbuf.DateUnit {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.DateUnit, 0, @"#self".@"#ref", @enumFromInt(1));
                    }
                };

                /// Exact decimal value represented as an integer value in two's
                /// complement. Currently 32-bit (4-byte), 64-bit (8-byte),
                /// 128-bit (16-byte) and 256-bit (32-byte) integers are used.
                /// The representation uses the endianness indicated in the Schema.
                pub const Decimal = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[5];
                    pub const @"#constructor" = struct {
                        precision: i32 = 0,
                        scale: i32 = 0,
                        bitWidth: i32 = 128,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Total number of decimal digits
                    pub fn precision(@"#self": Decimal) i32 {
                        return flatbuffers.decodeScalarField(i32, 0, @"#self".@"#ref", 0);
                    }

                    /// Number of digits after the decimal point "."
                    pub fn scale(@"#self": Decimal) i32 {
                        return flatbuffers.decodeScalarField(i32, 1, @"#self".@"#ref", 0);
                    }

                    /// Number of bits per value. The accepted widths are 32, 64, 128 and 256.
                    /// We use bitWidth for consistency with Int::bitWidth.
                    pub fn bitWidth(@"#self": Decimal) i32 {
                        return flatbuffers.decodeScalarField(i32, 2, @"#self".@"#ref", 128);
                    }
                };

                /// For sending dictionary encoding information. Any Field can be
                /// dictionary-encoded, but in this case none of its children may be
                /// dictionary-encoded.
                /// There is one vector / column per dictionary, but that vector / column
                /// may be spread across multiple dictionary batches by using the isDelta
                /// flag
                pub const DictionaryBatch = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[6];
                    pub const @"#constructor" = struct {
                        id: i64 = 0,
                        data: ?org.apache.arrow.flatbuf.RecordBatch = null,
                        isDelta: bool = false,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn id(@"#self": DictionaryBatch) i64 {
                        return flatbuffers.decodeScalarField(i64, 0, @"#self".@"#ref", 0);
                    }

                    pub fn data(@"#self": DictionaryBatch) ?org.apache.arrow.flatbuf.RecordBatch {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.RecordBatch, 1, @"#self".@"#ref");
                    }

                    /// If isDelta is true the values in the dictionary are to be appended to a
                    /// dictionary with the indicated id. If isDelta is false this dictionary
                    /// should replace the existing dictionary.
                    pub fn isDelta(@"#self": DictionaryBatch) bool {
                        return flatbuffers.decodeScalarField(bool, 2, @"#self".@"#ref", false);
                    }
                };

                pub const DictionaryEncoding = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[7];
                    pub const @"#constructor" = struct {
                        id: i64 = 0,
                        indexType: ?org.apache.arrow.flatbuf.Int = null,
                        isOrdered: bool = false,
                        dictionaryKind: org.apache.arrow.flatbuf.DictionaryKind = @enumFromInt(0),
                    };

                    @"#ref": flatbuffers.Ref,

                    /// The known dictionary id in the application where this data is used. In
                    /// the file or streaming formats, the dictionary ids are found in the
                    /// DictionaryBatch messages
                    pub fn id(@"#self": DictionaryEncoding) i64 {
                        return flatbuffers.decodeScalarField(i64, 0, @"#self".@"#ref", 0);
                    }

                    /// The dictionary indices are constrained to be non-negative integers. If
                    /// this field is null, the indices must be signed int32. To maximize
                    /// cross-language compatibility and performance, implementations are
                    /// recommended to prefer signed integer types over unsigned integer types
                    /// and to avoid uint64 indices unless they are required by an application.
                    pub fn indexType(@"#self": DictionaryEncoding) ?org.apache.arrow.flatbuf.Int {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Int, 1, @"#self".@"#ref");
                    }

                    /// By default, dictionaries are not ordered, or the order does not have
                    /// semantic meaning. In some statistical, applications, dictionary-encoding
                    /// is used to represent ordered categorical data, and we provide a way to
                    /// preserve that metadata here
                    pub fn isOrdered(@"#self": DictionaryEncoding) bool {
                        return flatbuffers.decodeScalarField(bool, 2, @"#self".@"#ref", false);
                    }

                    pub fn dictionaryKind(@"#self": DictionaryEncoding) org.apache.arrow.flatbuf.DictionaryKind {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.DictionaryKind, 3, @"#self".@"#ref", @enumFromInt(0));
                    }
                };

                pub const Duration = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[8];
                    pub const @"#constructor" = struct {
                        unit: org.apache.arrow.flatbuf.TimeUnit = @enumFromInt(1),
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn unit(@"#self": Duration) org.apache.arrow.flatbuf.TimeUnit {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.TimeUnit, 0, @"#self".@"#ref", @enumFromInt(1));
                    }
                };

                /// ----------------------------------------------------------------------
                /// A field represents a named column in a record / row batch or child of a
                /// nested type.
                pub const Field = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[9];
                    pub const @"#constructor" = struct {
                        name: ?[]const u8 = null,
                        nullable: bool = false,
                        type_type: org.apache.arrow.flatbuf.Type = .NONE,
                        dictionary: ?org.apache.arrow.flatbuf.DictionaryEncoding = null,
                        children: ?[]const org.apache.arrow.flatbuf.Field = null,
                        custom_metadata: ?[]const org.apache.arrow.flatbuf.KeyValue = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Name is not required (e.g., in a List)
                    pub fn name(@"#self": Field) ?flatbuffers.String {
                        return flatbuffers.decodeStringField(0, @"#self".@"#ref");
                    }

                    /// Whether or not this field can contain nulls. Should be true in general.
                    pub fn nullable(@"#self": Field) bool {
                        return flatbuffers.decodeScalarField(bool, 1, @"#self".@"#ref", false);
                    }

                    pub fn type_type(@"#self": Field) org.apache.arrow.flatbuf.Type {
                        return flatbuffers.decodeUnionField(org.apache.arrow.flatbuf.Type, 2, 3, @"#self".@"#ref");
                    }

                    /// Present only if the field is dictionary encoded.
                    pub fn dictionary(@"#self": Field) ?org.apache.arrow.flatbuf.DictionaryEncoding {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.DictionaryEncoding, 4, @"#self".@"#ref");
                    }

                    /// children apply only to nested data types like Struct, List and Union. For
                    /// primitive types children will have length 0.
                    pub fn children(@"#self": Field) ?flatbuffers.Vector(org.apache.arrow.flatbuf.Field) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Field, 5, @"#self".@"#ref");
                    }

                    /// User-defined metadata
                    pub fn custom_metadata(@"#self": Field) ?flatbuffers.Vector(org.apache.arrow.flatbuf.KeyValue) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.KeyValue, 6, @"#self".@"#ref");
                    }
                };

                pub const FixedSizeBinary = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[10];
                    pub const @"#constructor" = struct {
                        byteWidth: i32 = 0,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Number of bytes per value
                    pub fn byteWidth(@"#self": FixedSizeBinary) i32 {
                        return flatbuffers.decodeScalarField(i32, 0, @"#self".@"#ref", 0);
                    }
                };

                pub const FixedSizeList = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[11];
                    pub const @"#constructor" = struct {
                        listSize: i32 = 0,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Number of list items per value
                    pub fn listSize(@"#self": FixedSizeList) i32 {
                        return flatbuffers.decodeScalarField(i32, 0, @"#self".@"#ref", 0);
                    }
                };

                pub const FloatingPoint = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[12];
                    pub const @"#constructor" = struct {
                        precision: org.apache.arrow.flatbuf.Precision = @enumFromInt(0),
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn precision(@"#self": FloatingPoint) org.apache.arrow.flatbuf.Precision {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.Precision, 0, @"#self".@"#ref", @enumFromInt(0));
                    }
                };

                /// ----------------------------------------------------------------------
                /// Arrow File metadata
                ///
                pub const Footer = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[13];
                    pub const @"#constructor" = struct {
                        version: org.apache.arrow.flatbuf.MetadataVersion = @enumFromInt(0),
                        schema: ?org.apache.arrow.flatbuf.Schema = null,
                        dictionaries: ?[]const org.apache.arrow.flatbuf.Block = null,
                        recordBatches: ?[]const org.apache.arrow.flatbuf.Block = null,
                        custom_metadata: ?[]const org.apache.arrow.flatbuf.KeyValue = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn version(@"#self": Footer) org.apache.arrow.flatbuf.MetadataVersion {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.MetadataVersion, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    pub fn schema(@"#self": Footer) ?org.apache.arrow.flatbuf.Schema {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Schema, 1, @"#self".@"#ref");
                    }

                    pub fn dictionaries(@"#self": Footer) ?flatbuffers.Vector(org.apache.arrow.flatbuf.Block) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Block, 2, @"#self".@"#ref");
                    }

                    pub fn recordBatches(@"#self": Footer) ?flatbuffers.Vector(org.apache.arrow.flatbuf.Block) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Block, 3, @"#self".@"#ref");
                    }

                    /// User-defined metadata
                    pub fn custom_metadata(@"#self": Footer) ?flatbuffers.Vector(org.apache.arrow.flatbuf.KeyValue) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.KeyValue, 4, @"#self".@"#ref");
                    }
                };

                pub const Int = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[14];
                    pub const @"#constructor" = struct {
                        bitWidth: i32 = 0,
                        is_signed: bool = false,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn bitWidth(@"#self": Int) i32 {
                        return flatbuffers.decodeScalarField(i32, 0, @"#self".@"#ref", 0);
                    }

                    pub fn is_signed(@"#self": Int) bool {
                        return flatbuffers.decodeScalarField(bool, 1, @"#self".@"#ref", false);
                    }
                };

                pub const Interval = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[15];
                    pub const @"#constructor" = struct {
                        unit: org.apache.arrow.flatbuf.IntervalUnit = @enumFromInt(0),
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn unit(@"#self": Interval) org.apache.arrow.flatbuf.IntervalUnit {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.IntervalUnit, 0, @"#self".@"#ref", @enumFromInt(0));
                    }
                };

                /// ----------------------------------------------------------------------
                /// user defined key value pairs to add custom metadata to arrow
                /// key namespacing is the responsibility of the user
                pub const KeyValue = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[16];
                    pub const @"#constructor" = struct {
                        key: ?[]const u8 = null,
                        value: ?[]const u8 = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn key(@"#self": KeyValue) ?flatbuffers.String {
                        return flatbuffers.decodeStringField(0, @"#self".@"#ref");
                    }

                    pub fn value(@"#self": KeyValue) ?flatbuffers.String {
                        return flatbuffers.decodeStringField(1, @"#self".@"#ref");
                    }
                };

                /// Same as Binary, but with 64-bit offsets, allowing to represent
                /// extremely large data values.
                pub const LargeBinary = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[17];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Same as List, but with 64-bit offsets, allowing to represent
                /// extremely large data values.
                pub const LargeList = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[18];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Same as ListView, but with 64-bit offsets and sizes, allowing to represent
                /// extremely large data values.
                pub const LargeListView = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[19];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Same as Utf8, but with 64-bit offsets, allowing to represent
                /// extremely large data values.
                pub const LargeUtf8 = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[20];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                pub const List = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[21];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Represents the same logical types that List can, but contains offsets and
                /// sizes allowing for writes in any order and sharing of child values among
                /// list values.
                pub const ListView = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[22];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// A Map is a logical nested type that is represented as
                ///
                /// List<entries: Struct<key: K, value: V>>
                ///
                /// In this layout, the keys and values are each respectively contiguous. We do
                /// not constrain the key and value types, so the application is responsible
                /// for ensuring that the keys are hashable and unique. Whether the keys are sorted
                /// may be set in the metadata for this field.
                ///
                /// In a field with Map type, the field has a child Struct field, which then
                /// has two children: key type and the second the value type. The names of the
                /// child fields may be respectively "entries", "key", and "value", but this is
                /// not enforced.
                ///
                /// Map
                /// ```text
                ///   - child[0] entries: Struct
                ///     - child[0] key: K
                ///     - child[1] value: V
                /// ```
                /// Neither the "entries" field nor the "key" field may be nullable.
                ///
                /// The metadata is structured so that Arrow systems without special handling
                /// for Map can make Map an alias for List. The "layout" attribute for the Map
                /// field must have the same contents as a List.
                pub const Map = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[23];
                    pub const @"#constructor" = struct {
                        keysSorted: bool = false,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Set to true if the keys within each value are sorted
                    pub fn keysSorted(@"#self": Map) bool {
                        return flatbuffers.decodeScalarField(bool, 0, @"#self".@"#ref", false);
                    }
                };

                pub const Message = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[24];
                    pub const @"#constructor" = struct {
                        version: org.apache.arrow.flatbuf.MetadataVersion = @enumFromInt(0),
                        header_type: org.apache.arrow.flatbuf.MessageHeader = .NONE,
                        bodyLength: i64 = 0,
                        custom_metadata: ?[]const org.apache.arrow.flatbuf.KeyValue = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn version(@"#self": Message) org.apache.arrow.flatbuf.MetadataVersion {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.MetadataVersion, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    pub fn header_type(@"#self": Message) org.apache.arrow.flatbuf.MessageHeader {
                        return flatbuffers.decodeUnionField(org.apache.arrow.flatbuf.MessageHeader, 1, 2, @"#self".@"#ref");
                    }

                    pub fn bodyLength(@"#self": Message) i64 {
                        return flatbuffers.decodeScalarField(i64, 3, @"#self".@"#ref", 0);
                    }

                    pub fn custom_metadata(@"#self": Message) ?flatbuffers.Vector(org.apache.arrow.flatbuf.KeyValue) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.KeyValue, 4, @"#self".@"#ref");
                    }
                };

                /// These are stored in the flatbuffer in the Type union below
                pub const Null = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[25];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// A data header describing the shared memory layout of a "record" or "row"
                /// batch. Some systems call this a "row batch" internally and others a "record
                /// batch".
                pub const RecordBatch = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[26];
                    pub const @"#constructor" = struct {
                        length: i64 = 0,
                        nodes: ?[]const org.apache.arrow.flatbuf.FieldNode = null,
                        buffers: ?[]const org.apache.arrow.flatbuf.Buffer = null,
                        compression: ?org.apache.arrow.flatbuf.BodyCompression = null,
                        variadicBufferCounts: ?[]const i64 = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// number of records / rows. The arrays in the batch should all have this
                    /// length
                    pub fn length(@"#self": RecordBatch) i64 {
                        return flatbuffers.decodeScalarField(i64, 0, @"#self".@"#ref", 0);
                    }

                    /// Nodes correspond to the pre-ordered flattened logical schema
                    pub fn nodes(@"#self": RecordBatch) ?flatbuffers.Vector(org.apache.arrow.flatbuf.FieldNode) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.FieldNode, 1, @"#self".@"#ref");
                    }

                    /// Buffers correspond to the pre-ordered flattened buffer tree
                    ///
                    /// The number of buffers appended to this list depends on the schema. For
                    /// example, most primitive arrays will have 2 buffers, 1 for the validity
                    /// bitmap and 1 for the values. For struct arrays, there will only be a
                    /// single buffer for the validity (nulls) bitmap
                    pub fn buffers(@"#self": RecordBatch) ?flatbuffers.Vector(org.apache.arrow.flatbuf.Buffer) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Buffer, 2, @"#self".@"#ref");
                    }

                    /// Optional compression of the message body
                    pub fn compression(@"#self": RecordBatch) ?org.apache.arrow.flatbuf.BodyCompression {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.BodyCompression, 3, @"#self".@"#ref");
                    }

                    /// Some types such as Utf8View are represented using a variable number of buffers.
                    /// For each such Field in the pre-ordered flattened logical schema, there will be
                    /// an entry in variadicBufferCounts to indicate the number of number of variadic
                    /// buffers which belong to that Field in the current RecordBatch.
                    ///
                    /// For example, the schema
                    ///     col1: Struct<alpha: Int32, beta: BinaryView, gamma: Float64>
                    ///     col2: Utf8View
                    /// contains two Fields with variadic buffers so variadicBufferCounts will have
                    /// two entries, the first counting the variadic buffers of `col1.beta` and the
                    /// second counting `col2`'s.
                    ///
                    /// This field may be omitted if and only if the schema contains no Fields with
                    /// a variable number of buffers, such as BinaryView and Utf8View.
                    pub fn variadicBufferCounts(@"#self": RecordBatch) ?flatbuffers.Vector(i64) {
                        return flatbuffers.decodeVectorField(i64, 4, @"#self".@"#ref");
                    }
                };

                /// Contains two child arrays, run_ends and values.
                /// The run_ends child array must be a 16/32/64-bit integer array
                /// which encodes the indices at which the run with the value in
                /// each corresponding index in the values child array ends.
                /// Like list/struct types, the value array can be of any type.
                pub const RunEndEncoded = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[27];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// ----------------------------------------------------------------------
                /// A Schema describes the columns in a row batch
                pub const Schema = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[28];
                    pub const @"#constructor" = struct {
                        endianness: org.apache.arrow.flatbuf.Endianness = @enumFromInt(0),
                        fields: ?[]const org.apache.arrow.flatbuf.Field = null,
                        custom_metadata: ?[]const org.apache.arrow.flatbuf.KeyValue = null,
                        features: ?[]const i64 = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// endianness of the buffer
                    /// it is Little Endian by default
                    /// if endianness doesn't match the underlying system then the vectors need to be converted
                    pub fn endianness(@"#self": Schema) org.apache.arrow.flatbuf.Endianness {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.Endianness, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    pub fn fields(@"#self": Schema) ?flatbuffers.Vector(org.apache.arrow.flatbuf.Field) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Field, 1, @"#self".@"#ref");
                    }

                    pub fn custom_metadata(@"#self": Schema) ?flatbuffers.Vector(org.apache.arrow.flatbuf.KeyValue) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.KeyValue, 2, @"#self".@"#ref");
                    }

                    /// Features used in the stream/file.
                    pub fn features(@"#self": Schema) ?flatbuffers.Vector(i64) {
                        return flatbuffers.decodeVectorField(i64, 3, @"#self".@"#ref");
                    }
                };

                /// Compressed Sparse format, that is matrix-specific.
                pub const SparseMatrixIndexCSX = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[29];
                    pub const @"#constructor" = struct {
                        compressedAxis: org.apache.arrow.flatbuf.SparseMatrixCompressedAxis = @enumFromInt(0),
                        indptrType: org.apache.arrow.flatbuf.Int,
                        indptrBuffer: org.apache.arrow.flatbuf.Buffer,
                        indicesType: org.apache.arrow.flatbuf.Int,
                        indicesBuffer: org.apache.arrow.flatbuf.Buffer,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Which axis, row or column, is compressed
                    pub fn compressedAxis(@"#self": SparseMatrixIndexCSX) org.apache.arrow.flatbuf.SparseMatrixCompressedAxis {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.SparseMatrixCompressedAxis, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    /// The type of values in indptrBuffer
                    pub fn indptrType(@"#self": SparseMatrixIndexCSX) org.apache.arrow.flatbuf.Int {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Int, 1, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseMatrixIndexCSX.indptrType field");
                    }

                    /// indptrBuffer stores the location and size of indptr array that
                    /// represents the range of the rows.
                    /// The i-th row spans from `indptr[i]` to `indptr[i+1]` in the data.
                    /// The length of this array is 1 + (the number of rows), and the type
                    /// of index value is long.
                    ///
                    /// For example, let X be the following 6x4 matrix:
                    /// ```text
                    ///   X := [[0, 1, 2, 0],
                    ///         [0, 0, 3, 0],
                    ///         [0, 4, 0, 5],
                    ///         [0, 0, 0, 0],
                    ///         [6, 0, 7, 8],
                    ///         [0, 9, 0, 0]].
                    /// ```
                    /// The array of non-zero values in X is:
                    /// ```text
                    ///   values(X) = [1, 2, 3, 4, 5, 6, 7, 8, 9].
                    /// ```
                    /// And the indptr of X is:
                    /// ```text
                    ///   indptr(X) = [0, 2, 3, 5, 5, 8, 10].
                    /// ```
                    pub fn indptrBuffer(@"#self": SparseMatrixIndexCSX) org.apache.arrow.flatbuf.Buffer {
                        return flatbuffers.decodeStructField(org.apache.arrow.flatbuf.Buffer, 2, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseMatrixIndexCSX.indptrBuffer field");
                    }

                    /// The type of values in indicesBuffer
                    pub fn indicesType(@"#self": SparseMatrixIndexCSX) org.apache.arrow.flatbuf.Int {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Int, 3, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseMatrixIndexCSX.indicesType field");
                    }

                    /// indicesBuffer stores the location and size of the array that
                    /// contains the column indices of the corresponding non-zero values.
                    /// The type of index value is long.
                    ///
                    /// For example, the indices of the above X is:
                    /// ```text
                    ///   indices(X) = [1, 2, 2, 1, 3, 0, 2, 3, 1].
                    /// ```
                    /// Note that the indices are sorted in lexicographical order for each row.
                    pub fn indicesBuffer(@"#self": SparseMatrixIndexCSX) org.apache.arrow.flatbuf.Buffer {
                        return flatbuffers.decodeStructField(org.apache.arrow.flatbuf.Buffer, 4, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseMatrixIndexCSX.indicesBuffer field");
                    }
                };

                pub const SparseTensor = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[30];
                    pub const @"#constructor" = struct {
                        type_type: org.apache.arrow.flatbuf.Type = .NONE,
                        shape: []const org.apache.arrow.flatbuf.TensorDim,
                        non_zero_length: i64 = 0,
                        sparseIndex_type: org.apache.arrow.flatbuf.SparseTensorIndex = .NONE,
                        data: org.apache.arrow.flatbuf.Buffer,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn type_type(@"#self": SparseTensor) org.apache.arrow.flatbuf.Type {
                        return flatbuffers.decodeUnionField(org.apache.arrow.flatbuf.Type, 0, 1, @"#self".@"#ref");
                    }

                    /// The dimensions of the tensor, optionally named.
                    pub fn shape(@"#self": SparseTensor) flatbuffers.Vector(org.apache.arrow.flatbuf.TensorDim) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.TensorDim, 2, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensor.shape field");
                    }

                    /// The number of non-zero values in a sparse tensor.
                    pub fn non_zero_length(@"#self": SparseTensor) i64 {
                        return flatbuffers.decodeScalarField(i64, 3, @"#self".@"#ref", 0);
                    }

                    pub fn sparseIndex_type(@"#self": SparseTensor) org.apache.arrow.flatbuf.SparseTensorIndex {
                        return flatbuffers.decodeUnionField(org.apache.arrow.flatbuf.SparseTensorIndex, 4, 5, @"#self".@"#ref");
                    }

                    /// The location and size of the tensor's data
                    pub fn data(@"#self": SparseTensor) org.apache.arrow.flatbuf.Buffer {
                        return flatbuffers.decodeStructField(org.apache.arrow.flatbuf.Buffer, 6, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensor.data field");
                    }
                };

                /// ----------------------------------------------------------------------
                /// EXPERIMENTAL: Data structures for sparse tensors
                /// Coordinate (COO) format of sparse tensor index.
                ///
                /// COO's index list are represented as a NxM matrix,
                /// where N is the number of non-zero values,
                /// and M is the number of dimensions of a sparse tensor.
                ///
                /// indicesBuffer stores the location and size of the data of this indices
                /// matrix.  The value type and the stride of the indices matrix is
                /// specified in indicesType and indicesStrides fields.
                ///
                /// For example, let X be a 2x3x4x5 tensor, and it has the following
                /// 6 non-zero values:
                /// ```text
                ///   X[0, 1, 2, 0] := 1
                ///   X[1, 1, 2, 3] := 2
                ///   X[0, 2, 1, 0] := 3
                ///   X[0, 1, 3, 0] := 4
                ///   X[0, 1, 2, 1] := 5
                ///   X[1, 2, 0, 4] := 6
                /// ```
                /// In COO format, the index matrix of X is the following 4x6 matrix:
                /// ```text
                ///   [[0, 0, 0, 0, 1, 1],
                ///    [1, 1, 1, 2, 1, 2],
                ///    [2, 2, 3, 1, 2, 0],
                ///    [0, 1, 0, 0, 3, 4]]
                /// ```
                /// When isCanonical is true, the indices is sorted in lexicographical order
                /// (row-major order), and it does not have duplicated entries.  Otherwise,
                /// the indices may not be sorted, or may have duplicated entries.
                pub const SparseTensorIndexCOO = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[31];
                    pub const @"#constructor" = struct {
                        indicesType: org.apache.arrow.flatbuf.Int,
                        indicesStrides: ?[]const i64 = null,
                        indicesBuffer: org.apache.arrow.flatbuf.Buffer,
                        isCanonical: bool = false,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// The type of values in indicesBuffer
                    pub fn indicesType(@"#self": SparseTensorIndexCOO) org.apache.arrow.flatbuf.Int {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Int, 0, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCOO.indicesType field");
                    }

                    /// Non-negative byte offsets to advance one value cell along each dimension
                    /// If omitted, default to row-major order (C-like).
                    pub fn indicesStrides(@"#self": SparseTensorIndexCOO) ?flatbuffers.Vector(i64) {
                        return flatbuffers.decodeVectorField(i64, 1, @"#self".@"#ref");
                    }

                    /// The location and size of the indices matrix's data
                    pub fn indicesBuffer(@"#self": SparseTensorIndexCOO) org.apache.arrow.flatbuf.Buffer {
                        return flatbuffers.decodeStructField(org.apache.arrow.flatbuf.Buffer, 2, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCOO.indicesBuffer field");
                    }

                    /// This flag is true if and only if the indices matrix is sorted in
                    /// row-major order, and does not have duplicated entries.
                    /// This sort order is the same as of Tensorflow's SparseTensor,
                    /// but it is inverse order of SciPy's canonical coo_matrix
                    /// (SciPy employs column-major order for its coo_matrix).
                    pub fn isCanonical(@"#self": SparseTensorIndexCOO) bool {
                        return flatbuffers.decodeScalarField(bool, 3, @"#self".@"#ref", false);
                    }
                };

                /// Compressed Sparse Fiber (CSF) sparse tensor index.
                pub const SparseTensorIndexCSF = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[32];
                    pub const @"#constructor" = struct {
                        indptrType: org.apache.arrow.flatbuf.Int,
                        indptrBuffers: []const org.apache.arrow.flatbuf.Buffer,
                        indicesType: org.apache.arrow.flatbuf.Int,
                        indicesBuffers: []const org.apache.arrow.flatbuf.Buffer,
                        axisOrder: []const i32,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// CSF is a generalization of compressed sparse row (CSR) index.
                    /// See [smith2017knl](http://shaden.io/pub-files/smith2017knl.pdf)
                    ///
                    /// CSF index recursively compresses each dimension of a tensor into a set
                    /// of prefix trees. Each path from a root to leaf forms one tensor
                    /// non-zero index. CSF is implemented with two arrays of buffers and one
                    /// arrays of integers.
                    ///
                    /// For example, let X be a 2x3x4x5 tensor and let it have the following
                    /// 8 non-zero values:
                    /// ```text
                    ///   X[0, 0, 0, 1] := 1
                    ///   X[0, 0, 0, 2] := 2
                    ///   X[0, 1, 0, 0] := 3
                    ///   X[0, 1, 0, 2] := 4
                    ///   X[0, 1, 1, 0] := 5
                    ///   X[1, 1, 1, 0] := 6
                    ///   X[1, 1, 1, 1] := 7
                    ///   X[1, 1, 1, 2] := 8
                    /// ```
                    /// As a prefix tree this would be represented as:
                    /// ```text
                    ///         0          1
                    ///        / \         |
                    ///       0   1        1
                    ///      /   / \       |
                    ///     0   0   1      1
                    ///    /|  /|   |    /| |
                    ///   1 2 0 2   0   0 1 2
                    /// ```
                    /// The type of values in indptrBuffers
                    pub fn indptrType(@"#self": SparseTensorIndexCSF) org.apache.arrow.flatbuf.Int {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Int, 0, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCSF.indptrType field");
                    }

                    /// indptrBuffers stores the sparsity structure.
                    /// Each two consecutive dimensions in a tensor correspond to a buffer in
                    /// indptrBuffers. A pair of consecutive values at `indptrBuffers[dim][i]`
                    /// and `indptrBuffers[dim][i + 1]` signify a range of nodes in
                    /// `indicesBuffers[dim + 1]` who are children of `indicesBuffers[dim][i]` node.
                    ///
                    /// For example, the indptrBuffers for the above X is:
                    /// ```text
                    ///   indptrBuffer(X) = [
                    ///                       [0, 2, 3],
                    ///                       [0, 1, 3, 4],
                    ///                       [0, 2, 4, 5, 8]
                    ///                     ].
                    /// ```
                    pub fn indptrBuffers(@"#self": SparseTensorIndexCSF) flatbuffers.Vector(org.apache.arrow.flatbuf.Buffer) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Buffer, 1, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCSF.indptrBuffers field");
                    }

                    /// The type of values in indicesBuffers
                    pub fn indicesType(@"#self": SparseTensorIndexCSF) org.apache.arrow.flatbuf.Int {
                        return flatbuffers.decodeTableField(org.apache.arrow.flatbuf.Int, 2, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCSF.indicesType field");
                    }

                    /// indicesBuffers stores values of nodes.
                    /// Each tensor dimension corresponds to a buffer in indicesBuffers.
                    /// For example, the indicesBuffers for the above X is:
                    /// ```text
                    ///   indicesBuffer(X) = [
                    ///                        [0, 1],
                    ///                        [0, 1, 1],
                    ///                        [0, 0, 1, 1],
                    ///                        [1, 2, 0, 2, 0, 0, 1, 2]
                    ///                      ].
                    /// ```
                    pub fn indicesBuffers(@"#self": SparseTensorIndexCSF) flatbuffers.Vector(org.apache.arrow.flatbuf.Buffer) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.Buffer, 3, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCSF.indicesBuffers field");
                    }

                    /// axisOrder stores the sequence in which dimensions were traversed to
                    /// produce the prefix tree.
                    /// For example, the axisOrder for the above X is:
                    /// ```text
                    ///   axisOrder(X) = [0, 1, 2, 3].
                    /// ```
                    pub fn axisOrder(@"#self": SparseTensorIndexCSF) flatbuffers.Vector(i32) {
                        return flatbuffers.decodeVectorField(i32, 4, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.SparseTensorIndexCSF.axisOrder field");
                    }
                };

                /// A Struct_ in the flatbuffer metadata is the same as an Arrow Struct
                /// (according to the physical memory layout). We used Struct_ here as
                /// Struct is a reserved word in Flatbuffers
                pub const Struct_ = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[33];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                pub const Tensor = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[34];
                    pub const @"#constructor" = struct {
                        type_type: org.apache.arrow.flatbuf.Type = .NONE,
                        shape: []const org.apache.arrow.flatbuf.TensorDim,
                        strides: ?[]const i64 = null,
                        data: org.apache.arrow.flatbuf.Buffer,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn type_type(@"#self": Tensor) org.apache.arrow.flatbuf.Type {
                        return flatbuffers.decodeUnionField(org.apache.arrow.flatbuf.Type, 0, 1, @"#self".@"#ref");
                    }

                    /// The dimensions of the tensor, optionally named
                    pub fn shape(@"#self": Tensor) flatbuffers.Vector(org.apache.arrow.flatbuf.TensorDim) {
                        return flatbuffers.decodeVectorField(org.apache.arrow.flatbuf.TensorDim, 2, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.Tensor.shape field");
                    }

                    /// Non-negative byte offsets to advance one value cell along each dimension
                    /// If omitted, default to row-major order (C-like).
                    pub fn strides(@"#self": Tensor) ?flatbuffers.Vector(i64) {
                        return flatbuffers.decodeVectorField(i64, 3, @"#self".@"#ref");
                    }

                    /// The location and size of the tensor's data
                    pub fn data(@"#self": Tensor) org.apache.arrow.flatbuf.Buffer {
                        return flatbuffers.decodeStructField(org.apache.arrow.flatbuf.Buffer, 4, @"#self".@"#ref") orelse
                            @panic("missing org.apache.arrow.flatbuf.Tensor.data field");
                    }
                };

                /// ----------------------------------------------------------------------
                /// Data structures for dense tensors
                /// Shape data for a single axis in a tensor
                pub const TensorDim = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[35];
                    pub const @"#constructor" = struct {
                        size: i64 = 0,
                        name: ?[]const u8 = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    /// Length of dimension
                    pub fn size(@"#self": TensorDim) i64 {
                        return flatbuffers.decodeScalarField(i64, 0, @"#self".@"#ref", 0);
                    }

                    /// Name of the dimension, optional
                    pub fn name(@"#self": TensorDim) ?flatbuffers.String {
                        return flatbuffers.decodeStringField(1, @"#self".@"#ref");
                    }
                };

                /// Time is either a 32-bit or 64-bit signed integer type representing an
                /// elapsed time since midnight, stored in either of four units: seconds,
                /// milliseconds, microseconds or nanoseconds.
                ///
                /// The integer `bitWidth` depends on the `unit` and must be one of the following:
                /// * SECOND and MILLISECOND: 32 bits
                /// * MICROSECOND and NANOSECOND: 64 bits
                ///
                /// The allowed values are between 0 (inclusive) and 86400 (=24*60*60) seconds
                /// (exclusive), adjusted for the time unit (for example, up to 86400000
                /// exclusive for the MILLISECOND unit).
                /// This definition doesn't allow for leap seconds. Time values from
                /// measurements with leap seconds will need to be corrected when ingesting
                /// into Arrow (for example by replacing the value 86400 with 86399).
                pub const Time = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[36];
                    pub const @"#constructor" = struct {
                        unit: org.apache.arrow.flatbuf.TimeUnit = @enumFromInt(1),
                        bitWidth: i32 = 32,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn unit(@"#self": Time) org.apache.arrow.flatbuf.TimeUnit {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.TimeUnit, 0, @"#self".@"#ref", @enumFromInt(1));
                    }

                    pub fn bitWidth(@"#self": Time) i32 {
                        return flatbuffers.decodeScalarField(i32, 1, @"#self".@"#ref", 32);
                    }
                };

                /// Timestamp is a 64-bit signed integer representing an elapsed time since a
                /// fixed epoch, stored in either of four units: seconds, milliseconds,
                /// microseconds or nanoseconds, and is optionally annotated with a timezone.
                ///
                /// Timestamp values do not include any leap seconds (in other words, all
                /// days are considered 86400 seconds long).
                ///
                /// Timestamps with a non-empty timezone
                /// ------------------------------------
                ///
                /// If a Timestamp column has a non-empty timezone value, its epoch is
                /// 1970-01-01 00:00:00 (January 1st 1970, midnight) in the *UTC* timezone
                /// (the Unix epoch), regardless of the Timestamp's own timezone.
                ///
                /// Therefore, timestamp values with a non-empty timezone correspond to
                /// physical points in time together with some additional information about
                /// how the data was obtained and/or how to display it (the timezone).
                ///
                ///   For example, the timestamp value 0 with the timezone string "Europe/Paris"
                ///   corresponds to "January 1st 1970, 00h00" in the UTC timezone, but the
                ///   application may prefer to display it as "January 1st 1970, 01h00" in
                ///   the Europe/Paris timezone (which is the same physical point in time).
                ///
                /// One consequence is that timestamp values with a non-empty timezone
                /// can be compared and ordered directly, since they all share the same
                /// well-known point of reference (the Unix epoch).
                ///
                /// Timestamps with an unset / empty timezone
                /// -----------------------------------------
                ///
                /// If a Timestamp column has no timezone value, its epoch is
                /// 1970-01-01 00:00:00 (January 1st 1970, midnight) in an *unknown* timezone.
                ///
                /// Therefore, timestamp values without a timezone cannot be meaningfully
                /// interpreted as physical points in time, but only as calendar / clock
                /// indications ("wall clock time") in an unspecified timezone.
                ///
                ///   For example, the timestamp value 0 with an empty timezone string
                ///   corresponds to "January 1st 1970, 00h00" in an unknown timezone: there
                ///   is not enough information to interpret it as a well-defined physical
                ///   point in time.
                ///
                /// One consequence is that timestamp values without a timezone cannot
                /// be reliably compared or ordered, since they may have different points of
                /// reference.  In particular, it is *not* possible to interpret an unset
                /// or empty timezone as the same as "UTC".
                ///
                /// Conversion between timezones
                /// ----------------------------
                ///
                /// If a Timestamp column has a non-empty timezone, changing the timezone
                /// to a different non-empty value is a metadata-only operation:
                /// the timestamp values need not change as their point of reference remains
                /// the same (the Unix epoch).
                ///
                /// However, if a Timestamp column has no timezone value, changing it to a
                /// non-empty value requires to think about the desired semantics.
                /// One possibility is to assume that the original timestamp values are
                /// relative to the epoch of the timezone being set; timestamp values should
                /// then adjusted to the Unix epoch (for example, changing the timezone from
                /// empty to "Europe/Paris" would require converting the timestamp values
                /// from "Europe/Paris" to "UTC", which seems counter-intuitive but is
                /// nevertheless correct).
                ///
                /// Guidelines for encoding data from external libraries
                /// ----------------------------------------------------
                ///
                /// Date & time libraries often have multiple different data types for temporal
                /// data. In order to ease interoperability between different implementations the
                /// Arrow project has some recommendations for encoding these types into a Timestamp
                /// column.
                ///
                /// An "instant" represents a physical point in time that has no relevant timezone
                /// (for example, astronomical data). To encode an instant, use a Timestamp with
                /// the timezone string set to "UTC", and make sure the Timestamp values
                /// are relative to the UTC epoch (January 1st 1970, midnight).
                ///
                /// A "zoned date-time" represents a physical point in time annotated with an
                /// informative timezone (for example, the timezone in which the data was
                /// recorded).  To encode a zoned date-time, use a Timestamp with the timezone
                /// string set to the name of the timezone, and make sure the Timestamp values
                /// are relative to the UTC epoch (January 1st 1970, midnight).
                ///
                ///  (There is some ambiguity between an instant and a zoned date-time with the
                ///   UTC timezone.  Both of these are stored the same in Arrow.  Typically,
                ///   this distinction does not matter.  If it does, then an application should
                ///   use custom metadata or an extension type to distinguish between the two cases.)
                ///
                /// An "offset date-time" represents a physical point in time combined with an
                /// explicit offset from UTC.  To encode an offset date-time, use a Timestamp
                /// with the timezone string set to the numeric timezone offset string
                /// (e.g. "+03:00"), and make sure the Timestamp values are relative to
                /// the UTC epoch (January 1st 1970, midnight).
                ///
                /// A "naive date-time" (also called "local date-time" in some libraries)
                /// represents a wall clock time combined with a calendar date, but with
                /// no indication of how to map this information to a physical point in time.
                /// Naive date-times must be handled with care because of this missing
                /// information, and also because daylight saving time (DST) may make
                /// some values ambiguous or nonexistent. A naive date-time may be
                /// stored as a struct with Date and Time fields. However, it may also be
                /// encoded into a Timestamp column with an empty timezone. The timestamp
                /// values should be computed "as if" the timezone of the date-time values
                /// was UTC; for example, the naive date-time "January 1st 1970, 00h00" would
                /// be encoded as timestamp value 0.
                pub const Timestamp = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[37];
                    pub const @"#constructor" = struct {
                        unit: org.apache.arrow.flatbuf.TimeUnit = @enumFromInt(0),
                        timezone: ?[]const u8 = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn unit(@"#self": Timestamp) org.apache.arrow.flatbuf.TimeUnit {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.TimeUnit, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    /// The timezone is an optional string indicating the name of a timezone,
                    /// one of:
                    ///
                    /// * As used in the Olson timezone database (the "tz database" or
                    ///   "tzdata"), such as "America/New_York".
                    /// * An absolute timezone offset of the form "+XX:XX" or "-XX:XX",
                    ///   such as "+07:30".
                    ///
                    /// Whether a timezone string is present indicates different semantics about
                    /// the data (see above).
                    pub fn timezone(@"#self": Timestamp) ?flatbuffers.String {
                        return flatbuffers.decodeStringField(1, @"#self".@"#ref");
                    }
                };

                /// A union is a complex type with children in Field
                /// By default ids in the type vector refer to the offsets in the children
                /// optionally typeIds provides an indirection between the child offset and the type id
                /// for each child `typeIds[offset]` is the id used in the type vector
                pub const Union = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[38];
                    pub const @"#constructor" = struct {
                        mode: org.apache.arrow.flatbuf.UnionMode = @enumFromInt(0),
                        typeIds: ?[]const i32 = null,
                    };

                    @"#ref": flatbuffers.Ref,

                    pub fn mode(@"#self": Union) org.apache.arrow.flatbuf.UnionMode {
                        return flatbuffers.decodeEnumField(org.apache.arrow.flatbuf.UnionMode, 0, @"#self".@"#ref", @enumFromInt(0));
                    }

                    pub fn typeIds(@"#self": Union) ?flatbuffers.Vector(i32) {
                        return flatbuffers.decodeVectorField(i32, 1, @"#self".@"#ref");
                    }
                };

                /// Unicode with UTF-8 encoding
                pub const Utf8 = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[39];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };

                /// Logically the same as Utf8, but the internal representation uses a view
                /// struct that contains the string length and either the string's entire data
                /// inline (for small strings) or an inlined prefix, an index of another buffer,
                /// and an offset pointing to a slice in that buffer (for non-small strings).
                ///
                /// Since it uses a variable number of data buffers, each Field with this type
                /// must have a corresponding entry in `variadicBufferCounts`.
                pub const Utf8View = struct {
                    pub const @"#kind" = flatbuffers.Kind.Table;
                    pub const @"#root" = &@"#schema";
                    pub const @"#type" = &@"#schema".tables[40];
                    pub const @"#constructor" = struct {};

                    @"#ref": flatbuffers.Ref,
                };
            };
        };
    };
};
