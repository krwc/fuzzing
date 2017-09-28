#!/bin/bash
set -e

. ./utils.sh

if [[ $# < 1 ]] ; then
    die "Usage: $0 test-name"
fi

DIRECTORY="$1"
if [[ -d "$DIRECTORY" ]]; then
    die "'$DIRECTORY' already exist! Pick up a different name"
fi

mkdir -p "$DIRECTORY" "$DIRECTORY/input" "$DIRECTORY/output" "$DIRECTORY/src"
echo '' > "$DIRECTORY/input/test"
cat >"$DIRECTORY/src/test.cpp" <<EOF
#include <cstdio>
#include <cstdlib>
#include <bits/stdc++.h>

int main(int argc, char **argv) {

}
EOF
