#!/usr/bin/env bash

if [[ -z "$1" ]]; then
    echo "Error: testdir not provided."
    exit 1
fi

TESTDIR="$1"
TESTDIR="${TESTDIR%/}/"

if [[ ! -d "$TESTDIR" ]]; then
    echo "Error: $TESTDIR is not a directory"
    exit 1
fi

opam switch default
eval $(opam env)
cp validation_tests/Holmakefile "$TESTDIR"
cd "$TESTDIR"
Holmake
cd ..
./petr4_json_export.sh "$TESTDIR" p4include/
./petr4_to_hol4p4_dir.sh "$TESTDIR" 1
mv petr4_to_hol4p4_stf.log "$TESTDIR"
cd "$TESTDIR"
Holmake -k

cd ..
PASS=$(ls "${TESTDIR%/}"/.hol/objs/*.uo | wc -l)
JSON_SUCCESS=$(find "$TESTDIR" -maxdepth 1 -name '*.json' -size +0c | wc -l)
TOTAL=$(ls "$TESTDIR"/*.p4 | wc -l)

echo "Total Tests: $TOTAL"
echo "Successful JSON outputs: $JSON_SUCCESS/$TOTAL"
echo "Pass: $PASS/$TOTAL"
