const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("flags.zon");

pub const Flags = struct {
    pub const Color = packed struct {
        pub const @"#kind" = flatbuffers.Kind.BitFlags;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".bit_flags[0];

        Red: bool = false,
        Green: bool = false,
        Blue: bool = false,
    };

    pub const Root = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".tables[0];
        pub const @"#constructor" = struct {
            colors: ?[]const Flags.Color = null,
        };

        @"#ref": flatbuffers.Ref,

        pub fn colors(@"#self": Root) ?flatbuffers.Vector(Flags.Color) {
            return flatbuffers.decodeVectorField(Flags.Color, 0, @"#self".@"#ref");
        }
    };
};
