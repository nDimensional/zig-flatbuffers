#!/usr/bin/env bash

generate_test() {
    name=$1
    # `flatc` is fetched as a build dependency, so it need not be installed locally.
    zig build flatc -- -b --schema --bfbs-comments --bfbs-builtins -o test/${name} test/${name}/${name}.fbs
    zig build parse -- test/${name}/${name}.bfbs > test/${name}/${name}.zon
    zig build generate -- test/${name}/${name}.zon | zig fmt --stdin > test/${name}/${name}.zig
}

generate_test "simple"
generate_test "monster"
generate_test "arrow"
