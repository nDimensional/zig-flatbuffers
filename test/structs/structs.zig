const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("structs.zon");

pub const Structs = struct {
    pub const Aligned = struct {
        pub const @"#kind" = flatbuffers.Kind.Struct;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".structs[0];
        value: i32,
    };

    pub const SegmentSpec = struct {
        pub const @"#kind" = flatbuffers.Kind.Struct;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".structs[1];
        _compression: u8,
        _encryption: u16,
        alignment_exponent: u8,
        length: u32,
        offset: u64,
    };

    pub const Root = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".tables[0];
        pub const @"#constructor" = struct {
            segments: ?[]const Structs.SegmentSpec = null,
            aligned: ?[]const Structs.Aligned = null,
        };

        @"#ref": flatbuffers.Ref,

        pub fn segments(@"#self": Root) ?flatbuffers.Vector(Structs.SegmentSpec) {
            return flatbuffers.decodeVectorField(Structs.SegmentSpec, 0, @"#self".@"#ref");
        }

        pub fn aligned(@"#self": Root) ?flatbuffers.Vector(Structs.Aligned) {
            return flatbuffers.decodeVectorField(Structs.Aligned, 1, @"#self".@"#ref");
        }
    };
};
