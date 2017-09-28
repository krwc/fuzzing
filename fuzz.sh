#!/bin/bash
set -e

. ./utils.sh

echo core | sudo tee /proc/sys/kernel/core_pattern
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

OTHER_ARGS=()

print_help() {
    cat <<EOF >&2
NAME
    $0 - run fuzz tests in an automated way.

SYNOPSIS
    $0 [ OPTIONS... ] [ OTHER ARGS... ]

OPTIONS
    -r, --harden
            - use afl hardening.
    -s, --sanitize
            - use AddressSanitizer during fuzzing.
    -h, --help
            - show this message and exit.

NOTES
    If the source dir of the fuzzed project contains CMakeLists.txt it is
    detected and cmake is used to perform build.

OTHER ARGS
    Everything that is not an option is passed to potentially spawned
    processes (like CMake).
EOF
}

FUZZ_WORKDIR="$1"
shift
FUZZ_BUILDDIR="build"
FUZZ_CFLAGS="-ggdb -O2"
FUZZ_CXXFLAGS="-ggdb -O2"
FUZZ_HARDEN=
FUZZ_USE_ASAN=

while [[ "$#" > 0 ]]; do
    case "$1" in
        --harden|-r)   shift; FUZZ_HARDEN=1; ;;
        --sanitize|-s) shift; FUZZ_USE_ASAN=1; ;;
        --help|-h)  print_help && exit 0 ;;
        *) OTHER_ARGS+=($1) ; shift ;;
    esac
done

echo "OTHER: ${OTHER_ARGS[@]}"
pushd "$FUZZ_WORKDIR"
    # Cleanup
    rm -rf "$FUZZ_BUILDDIR" && mkdir "$FUZZ_BUILDDIR"

    EXECUTABLES=()

    [[ "$FUZZ_HARDEN" ]] && export AFL_HARDEN=1
    [[ "$FUZZ_USE_ASAN" ]] && export AFL_USE_ASAN=1

    pushd "$FUZZ_BUILDDIR"
        # Handle CMake projects with grace
        if [ -e ../src/CMakeLists.txt ]; then
            CC=afl-clang \
                CXX=afl-clang++ \
                cmake ../src "${OTHER_ARGS[@]}" \
                    -DCMAKE_CXX_FLAGS="${FUZZ_CXXFLAGS}" \
                    -DCMAKE_C_FLAGS="${FUZZ_CFLAGS}"
            make || die "Compilation failed"
        else
            afl-clang++ ${FUZZ_CFLAGS} ../src/test.cpp
        fi
        EXECUTABLES=`find $(pwd) -maxdepth 1 -type f -executable`
    popd

    if "${#EXECUTABLES[@]}" -leq "1"; then
        die "Expected at most one executable, got: $EXECUTABLES"
    fi

    afl-fuzz -i input/ -o output/ "${EXECUTABLES[0]}"
popd
