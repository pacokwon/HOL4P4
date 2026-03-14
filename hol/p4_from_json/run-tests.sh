#!/usr/bin/env bash
set -euo pipefail

EXCLUDE_FILE=""

while getopts "e:" opt; do
  case "$opt" in
    e) EXCLUDE_FILE="$OPTARG" ;;
    *) echo "Usage: $0 [-e exclude_file] testdir"; exit 1 ;;
  esac
done

shift $((OPTIND - 1))

if [[ -z "${1:-}" ]]; then
    echo "Error: testdir not provided."
    exit 1
fi

TESTDIR="$1"
TESTDIR="${TESTDIR%/}/"

if [[ ! -d "$TESTDIR" ]]; then
    echo "Error: $TESTDIR is not a directory"
    exit 1
fi

EXCLUDED_DIR="${TESTDIR%/}/.excluded_tmp"
EXCLUDED_LIST="${TESTDIR%/}/.excluded_tests"

restore_excluded() {
    if [[ -d "$EXCLUDED_DIR" ]]; then
        find "$EXCLUDED_DIR" -maxdepth 1 -type f | while IFS= read -r f; do
            mv "$f" "$TESTDIR"
        done
        rmdir "$EXCLUDED_DIR" 2>/dev/null || true
    fi
    rm -f "$EXCLUDED_LIST"
}

trap restore_excluded EXIT

if [[ -n "$EXCLUDE_FILE" ]]; then
    if [[ ! -f "$EXCLUDE_FILE" ]]; then
        echo "Error: exclude file not found: $EXCLUDE_FILE"
        exit 1
    fi

    mkdir -p "$EXCLUDED_DIR"
    : > "$EXCLUDED_LIST"

    while IFS= read -r name || [[ -n "$name" ]]; do
        [[ -z "$name" ]] && continue

        echo "$name" >> "$EXCLUDED_LIST"

        p4_name="$name"
        stem="${name%.p4}"

        stem="${name%.p4}"
        stem="${stem%.stf}"
        stem="${stem%.json}"

        for f in \
            "$TESTDIR/$stem.p4" \
            "$TESTDIR/$stem.stf" \
            "$TESTDIR/$stem.json"
        do
            if [[ -f "$f" ]]; then
                mv "$f" "$EXCLUDED_DIR/"
            fi
        done
    done < "$EXCLUDE_FILE"
fi

python3 ../../scripts/patch-stf.py --in-place "$TESTDIR"

opam switch hol4p4
eval "$(opam env)"

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

PASS=$(find "${TESTDIR%/}/.hol/objs" -maxdepth 1 -name '*.uo' 2>/dev/null | wc -l)
JSON_SUCCESS=$(find "$TESTDIR" -maxdepth 1 -name '*.json' -size +0c | wc -l)
TOTAL=$(find "$TESTDIR" -maxdepth 1 -name '*.p4' | wc -l)
SKIPPED=0
[[ -f "$EXCLUDED_LIST" ]] && SKIPPED=$(wc -l < "$EXCLUDED_LIST")

LOG="${TESTDIR%/}.log"
./collect-stat.sh "$TESTDIR" > "$LOG"

echo "============================================="
echo "Total runnable Tests: $TOTAL"
echo "Excluded Tests: $SKIPPED"
echo "Successful JSON outputs: $JSON_SUCCESS/$TOTAL"
echo "Pass: $PASS/$TOTAL"
echo "Individual test results can be found in $LOG"
