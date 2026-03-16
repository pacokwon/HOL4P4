#!/usr/bin/env bash

JOBS=""

while getopts "j:" opt; do
  case "$opt" in
    j) JOBS="$OPTARG" ;;
    *) echo "Usage: $0 [-j jobs] testdir"; exit 1 ;;
  esac
done

shift $((OPTIND - 1))

# Default only if -j not provided
if [[ -z "$JOBS" ]]; then
    n=$(nproc)
    JOBS=$(( n > 1 ? n - 1 : 1 ))
fi

if [ -z "$1" ]; then
    echo "TESTDIR is empty"
    exit 1
fi

TESTDIR="$1"
TESTDIR="${TESTDIR%/}/"

opam switch hol4p4
eval "$(opam env)"

cp validation_tests/Holmakefile "$TESTDIR"

OBJ_DIR="${TESTDIR%/}/.hol/objs"

if [[ -d "$OBJ_DIR" ]] && find "$OBJ_DIR" -maxdepth 1 -name '*.uo' | grep -q .; then
    echo "Skipping first Holmake: existing .uo files found in $OBJ_DIR"
else
    cd "$TESTDIR"
    Holmake -j $JOBS -k || true
    cd ..
fi

./petr4_json_export.sh "$TESTDIR" /p4include
./petr4_to_hol4p4_dir.sh "$TESTDIR" $JOBS
mv petr4_to_hol4p4_stf.log "$TESTDIR"

cd "$TESTDIR"
Holmake -j $JOBS -k || true
cd ..
