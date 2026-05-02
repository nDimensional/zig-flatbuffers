#ifndef FLATCC_HELPERS_H
#define FLATCC_HELPERS_H

#include <stdint.h>
#include <stddef.h>

// Simple wrappers to avoid Zig's alignment issues with flatcc macros

typedef struct Eclectic_FooBar_table const* Eclectic_FooBar_table_ptr;

// Wrapper for Eclectic_FooBar_as_root
Eclectic_FooBar_table_ptr eclectic_foobar_read(const void* buffer);

// Wrapper for field accessors
int8_t eclectic_foobar_meal(Eclectic_FooBar_table_ptr table);
int16_t eclectic_foobar_height(Eclectic_FooBar_table_ptr table);
const char* eclectic_foobar_say(Eclectic_FooBar_table_ptr table);

// Builder helpers
int eclectic_foobar_build(void** out_buffer, size_t* out_size,
                          int8_t meal, const char* say, int16_t height);
void eclectic_foobar_free_buffer(void* buffer);

#endif
