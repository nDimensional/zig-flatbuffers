const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("simple.zon");

pub const Fruit = enum(i8) {
    pub const @"#kind" = flatbuffers.Kind.Enum;
    pub const @"#root" = &@"#schema";
    pub const @"#type" = &@"#schema".enums[0];

    Banana = -1,
    Orange = 42,
};

pub const FooBar = struct {
    pub const @"#kind" = flatbuffers.Kind.Table;
    pub const @"#root" = &@"#schema";
    pub const @"#type" = &@"#schema".tables[0];
    pub const @"#constructor" = struct {
        meal: Fruit = @enumFromInt(-1),
        say: ?[]const u8 = null,
        height: i16 = 0,
    };

    @"#ref": flatbuffers.Ref,

    pub fn meal(@"#self": FooBar) Fruit {
        return flatbuffers.decodeEnumField(Fruit, 0, @"#self".@"#ref", @enumFromInt(-1));
    }

    pub fn say(@"#self": FooBar) ?flatbuffers.String {
        return flatbuffers.decodeStringField(2, @"#self".@"#ref");
    }

    pub fn height(@"#self": FooBar) i16 {
        return flatbuffers.decodeScalarField(i16, 3, @"#self".@"#ref", 0);
    }
};
