const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("arrays.zon");

pub const Arrays = struct {
    pub const Block = struct {
        pub const @"#kind" = flatbuffers.Kind.Struct;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".structs[0];
        bytes: [3]u8,
        ints: [2]i32,
        doubles: [2]f64,
        points: [2]Arrays.Vec3,
    };

    pub const Vec3 = struct {
        pub const @"#kind" = flatbuffers.Kind.Struct;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".structs[1];
        x: f32,
        y: f32,
        z: f32,
    };

    pub const Root = struct {
        pub const @"#kind" = flatbuffers.Kind.Table;
        pub const @"#root" = &@"#schema";
        pub const @"#type" = &@"#schema".tables[0];
        pub const @"#constructor" = struct {
            block: ?Arrays.Block = null,
            blocks: ?[]const Arrays.Block = null,
        };

        @"#ref": flatbuffers.Ref,

        pub fn block(@"#self": Root) ?Arrays.Block {
            return flatbuffers.decodeStructField(Arrays.Block, 0, @"#self".@"#ref");
        }

        pub fn blocks(@"#self": Root) ?flatbuffers.Vector(Arrays.Block) {
            return flatbuffers.decodeVectorField(Arrays.Block, 1, @"#self".@"#ref");
        }
    };
};
