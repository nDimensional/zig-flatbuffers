#include "flatcc_helpers.h"
#include "flatcc/flatcc_builder.h"
#include "monster_builder.h"
#include "monster_reader.h"
#include <stdlib.h>
#include <string.h>

MyGame_Sample_Monster_table_ptr monster_read(const void* buffer) {
    const uint8_t* buf = (const uint8_t*)buffer;
    uint32_t root_offset = *(const uint32_t*)buf;
    return (MyGame_Sample_Monster_table_ptr)(buf + root_offset);
}

const char* monster_name(MyGame_Sample_Monster_table_ptr table) {
    return MyGame_Sample_Monster_name(table);
}

int16_t monster_hp(MyGame_Sample_Monster_table_ptr table) {
    return MyGame_Sample_Monster_hp(table);
}

int16_t monster_mana(MyGame_Sample_Monster_table_ptr table) {
    return MyGame_Sample_Monster_mana(table);
}

int8_t monster_color(MyGame_Sample_Monster_table_ptr table) {
    return MyGame_Sample_Monster_color(table);
}

Vec3 monster_pos(MyGame_Sample_Monster_table_ptr table) {
    MyGame_Sample_Vec3_struct_t pos_ptr = MyGame_Sample_Monster_pos(table);
    Vec3 result;
    if (pos_ptr) {
        result.x = MyGame_Sample_Vec3_x(pos_ptr);
        result.y = MyGame_Sample_Vec3_y(pos_ptr);
        result.z = MyGame_Sample_Vec3_z(pos_ptr);
    } else {
        result.x = 0.0f;
        result.y = 0.0f;
        result.z = 0.0f;
    }
    return result;
}

MyGame_Sample_Weapon_table_ptr weapon_read(const void* buffer) {
    const uint8_t* buf = (const uint8_t*)buffer;
    uint32_t root_offset = *(const uint32_t*)buf;
    return (MyGame_Sample_Weapon_table_ptr)(buf + root_offset);
}

const char* weapon_name(MyGame_Sample_Weapon_table_ptr table) {
    return MyGame_Sample_Weapon_name(table);
}

int16_t weapon_damage(MyGame_Sample_Weapon_table_ptr table) {
    return MyGame_Sample_Weapon_damage(table);
}

int monster_build_simple(void** out_buffer, size_t* out_size,
                         const char* name, int16_t hp, int16_t mana,
                         int8_t color, Vec3 pos) {
    flatcc_builder_t builder;
    void* buf;

    flatcc_builder_init(&builder);

    flatbuffers_string_ref_t name_ref = 0;
    if (name != NULL) {
        name_ref = flatbuffers_string_create_str(&builder, name);
    }

    MyGame_Sample_Vec3_t pos_struct = { pos.x, pos.y, pos.z };

    // Use top-down approach with start/end
    MyGame_Sample_Monster_start_as_root(&builder);
    MyGame_Sample_Monster_pos_add(&builder, &pos_struct);
    MyGame_Sample_Monster_mana_add(&builder, mana);
    MyGame_Sample_Monster_hp_add(&builder, hp);
    if (name_ref) {
        MyGame_Sample_Monster_name_add(&builder, name_ref);
    }
    MyGame_Sample_Monster_color_add(&builder, color);
    MyGame_Sample_Monster_end_as_root(&builder);

    // Now finalize the buffer - this extracts the completed buffer
    buf = flatcc_builder_finalize_buffer(&builder, out_size);

    // Clean up the builder
    flatcc_builder_clear(&builder);

    *out_buffer = buf;
    return buf ? 0 : -1;
}

void monster_free_buffer(void* buffer) {
    free(buffer);
}
