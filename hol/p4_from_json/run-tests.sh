#!/usr/bin/env bash

if [[ -z "$1" ]]; then
    echo "Error: testdir not provided."
    exit 1
fi

TESTDIR="$1"

if [[ ! -d "$TESTDIR" ]]; then
    echo "Error: $TESTDIR is not a directory"
    exit 1
fi

eval $(opam env)
cp validation_tests/Holmakefile "$TESTDIR"
cd "$TESTDIR"
Holmake
cd ..
./petr4_json_export.sh "$TESTDIR" p4include/
./petr4_to_hol4p4_dir.sh "$TESTDIR" 1
cd "$TESTDIR"
Holmake -k
