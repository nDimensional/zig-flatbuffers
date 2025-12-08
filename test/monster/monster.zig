const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("monster.zon");

pub const MyGame = struct {
    pub const Sample = struct {
        pub const Color = enum(i8) {
            pub const @"#kind" = flatbuffers.Kind.Enum;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".enums[0];

            Red = 0,
            Green = 1,
            Blue = 2,
        };

        pub const Vec3 = struct {
            pub const @"#kind" = flatbuffers.Kind.Struct;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".structs[0];
            x: f32,
            y: f32,
            z: f32,
        };

        pub const Equipment = union(enum(u8)) {
            pub const @"#kind" = flatbuffers.Kind.Union;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".unions[0];

            NONE: void = 0,
            Weapon: MyGame.Sample.Weapon = 1,
        };

        pub const Monster = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[0];
            pub const @"#constructor" = struct {
                pos: ?MyGame.Sample.Vec3 = null,
                mana: i16 = 150,
                hp: i16 = 100,
                name: ?[]const u8 = null,
                inventory: ?[]const u8 = null,
                color: MyGame.Sample.Color = @enumFromInt(2),
                weapons: ?[]const MyGame.Sample.Weapon = null,
                equipped_type: MyGame.Sample.Equipment = .NONE,
                path: ?[]const MyGame.Sample.Vec3 = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn pos(@"#self": Monster) ?MyGame.Sample.Vec3 {
                return flatbuffers.decodeStructField(MyGame.Sample.Vec3, 0, @"#self".@"#ref");
            }

            pub fn mana(@"#self": Monster) i16 {
                return flatbuffers.decodeScalarField(i16, 1, @"#self".@"#ref", 150);
            }

            pub fn hp(@"#self": Monster) i16 {
                return flatbuffers.decodeScalarField(i16, 2, @"#self".@"#ref", 100);
            }

            pub fn name(@"#self": Monster) ?flatbuffers.String {
                return flatbuffers.decodeStringField(3, @"#self".@"#ref");
            }

            pub fn inventory(@"#self": Monster) ?flatbuffers.Vector(u8) {
                return flatbuffers.decodeVectorField(u8, 5, @"#self".@"#ref");
            }

            pub fn color(@"#self": Monster) MyGame.Sample.Color {
                return flatbuffers.decodeEnumField(MyGame.Sample.Color, 6, @"#self".@"#ref", @enumFromInt(2));
            }

            pub fn weapons(@"#self": Monster) ?flatbuffers.Vector(MyGame.Sample.Weapon) {
                return flatbuffers.decodeVectorField(MyGame.Sample.Weapon, 7, @"#self".@"#ref");
            }

            pub fn equipped_type(@"#self": Monster) MyGame.Sample.Equipment {
                return flatbuffers.decodeUnionField(MyGame.Sample.Equipment, 8, 9, @"#self".@"#ref");
            }

            pub fn path(@"#self": Monster) ?flatbuffers.Vector(MyGame.Sample.Vec3) {
                return flatbuffers.decodeVectorField(MyGame.Sample.Vec3, 10, @"#self".@"#ref");
            }
        };

        pub const Weapon = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[1];
            pub const @"#constructor" = struct {
                name: ?[]const u8 = null,
                damage: i16 = 0,
            };

            @"#ref": flatbuffers.Ref,

            pub fn name(@"#self": Weapon) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn damage(@"#self": Weapon) i16 {
                return flatbuffers.decodeScalarField(i16, 1, @"#self".@"#ref", 0);
            }
        };
    };
};
