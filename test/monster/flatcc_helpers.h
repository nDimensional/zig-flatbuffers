#ifndef MONSTER_FLATCC_HELPERS_H
#define MONSTER_FLATCC_HELPERS_H

#include <stdint.h>
#include <stddef.h>

// Forward declarations
typedef struct MyGame_Sample_Monster_table const* MyGame_Sample_Monster_table_ptr;
typedef struct MyGame_Sample_Weapon_table const* MyGame_Sample_Weapon_table_ptr;

// Vec3 struct for positions
typedef struct {
    float x;
    float y;
    float z;
} Vec3;

// Reader helpers for Monster
MyGame_Sample_Monster_table_ptr monster_read(const void* buffer);
const char* monster_name(MyGame_Sample_Monster_table_ptr table);
int16_t monster_hp(MyGame_Sample_Monster_table_ptr table);
int16_t monster_mana(MyGame_Sample_Monster_table_ptr table);
int8_t monster_color(MyGame_Sample_Monster_table_ptr table);
Vec3 monster_pos(MyGame_Sample_Monster_table_ptr table);

// Reader helpers for Weapon
MyGame_Sample_Weapon_table_ptr weapon_read(const void* buffer);
const char* weapon_name(MyGame_Sample_Weapon_table_ptr table);
int16_t weapon_damage(MyGame_Sample_Weapon_table_ptr table);

// Builder helpers
// Build a simple Monster with name, hp, mana, color, and position
int monster_build_simple(void** out_buffer, size_t* out_size,
                         const char* name, int16_t hp, int16_t mana,
                         int8_t color, Vec3 pos);

// Build a Weapon
void* weapon_build(const char* name, int16_t damage, void* builder_context);

void monster_free_buffer(void* buffer);

#endif
