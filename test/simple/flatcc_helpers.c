#include "flatcc_helpers.h"
#include "flatcc/flatcc_builder.h"
#include "simple_builder.h"
#include "simple_reader.h"
#include <stdlib.h>
#include <string.h>

Eclectic_FooBar_table_ptr eclectic_foobar_read(const void* buffer) {
    // Use as_root_with_size which doesn't require file identifier
    // Actually, let's just cast directly - FlatBuffers root is at buffer + root_offset
    const uint8_t* buf = (const uint8_t*)buffer;
    uint32_t root_offset = *(const uint32_t*)buf;
    return (Eclectic_FooBar_table_ptr)(buf + root_offset);
}

int8_t eclectic_foobar_meal(Eclectic_FooBar_table_ptr table) {
    return Eclectic_FooBar_meal(table);
}

int16_t eclectic_foobar_height(Eclectic_FooBar_table_ptr table) {
    return Eclectic_FooBar_height(table);
}

const char* eclectic_foobar_say(Eclectic_FooBar_table_ptr table) {
    return Eclectic_FooBar_say(table);
}

int eclectic_foobar_build(void** out_buffer, size_t* out_size,
                          int8_t meal, const char* say, int16_t height) {
    flatcc_builder_t builder;

    if (flatcc_builder_init(&builder) != 0) {
        return -1;
    }

    flatbuffers_string_ref_t say_ref = 0;
    if (say != NULL) {
        say_ref = flatbuffers_string_create_str(&builder, say);
    }

    Eclectic_FooBar_create_as_root(&builder, meal, say_ref, height);

    *out_buffer = flatcc_builder_finalize_buffer(&builder, out_size);
    flatcc_builder_clear(&builder);

    return 0;
}

void eclectic_foobar_free_buffer(void* buffer) {
    free(buffer);
}
