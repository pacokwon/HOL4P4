#!/usr/bin/env bash

EXCLUDE_FILES=()
LOG_FILE=""

while getopts "e:o:" opt; do
  case "$opt" in
    e) EXCLUDE_FILES+=("$OPTARG") ;;
    o) LOG_FILE="$OPTARG" ;;
    *) echo "Usage: $0 [-e exclude_file ...] [-o logfile] testdir"; exit 1 ;;
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

TOTAL=$(find "$TESTDIR" -maxdepth 1 -name '*.p4' | wc -l)

EXCLUDED_DIR="${TESTDIR%/}/.excluded_tmp"
EXCLUDED_LIST="${TESTDIR%/}/.excluded_tests"

restore_excluded() {
    if [[ -d "$EXCLUDED_DIR" ]]; then
        find "$EXCLUDED_DIR" -maxdepth 1 -type f | while IFS= read -r f; do
            mv "$f" "$TESTDIR"
        done
        rmdir "$EXCLUDED_DIR" 2>/dev/null || true
    fi
}

trap restore_excluded EXIT

if [[ ${#EXCLUDE_FILES[@]} -gt 0 ]]; then
    mkdir -p "$EXCLUDED_DIR"
    : > "$EXCLUDED_LIST"

    for EXCLUDE_FILE in "${EXCLUDE_FILES[@]}"; do
        if [[ ! -f "$EXCLUDE_FILE" ]]; then
            echo "Error: exclude file not found: $EXCLUDE_FILE"
            exit 1
        fi

        while IFS= read -r name || [[ -n "$name" ]]; do
            [[ -z "$name" ]] && continue

            name=$(basename "$name")

            stem="${name%.p4}"
            stem="${stem%.stf}"
            stem="${stem%.json}"

            candidates=("$stem")

            if [[ "$stem" =~ ^(.*)_([0-9]+)$ ]]; then
                candidates+=("${BASH_REMATCH[1]}__${BASH_REMATCH[2]}")
            fi

            matched=0

            for cand in "${candidates[@]}"; do
                for f in \
                    "$TESTDIR/$cand.p4" \
                    "$TESTDIR/$cand.stf" \
                    "$TESTDIR/$cand.json"
                do
                    if [[ -f "$f" ]]; then
                        mv "$f" "$EXCLUDED_DIR/"
                        matched=1
                    fi
                done

                if [[ $matched -eq 1 ]]; then
                    echo "$cand.p4" >> "$EXCLUDED_LIST"
                    break
                fi
            done
        done < "$EXCLUDE_FILE"
    done

    sort -u -o "$EXCLUDED_LIST" "$EXCLUDED_LIST"
fi

python3 ../../scripts/patch-stf.py --in-place "$TESTDIR"

opam switch hol4p4
eval "$(opam env)"

cp validation_tests/Holmakefile "$TESTDIR"

OBJ_DIR="${TESTDIR%/}/.hol/objs"

if [[ -d "$OBJ_DIR" ]] && find "$OBJ_DIR" -maxdepth 1 -name '*.uo' | grep -q .; then
    echo "Skipping first Holmake: existing .uo files found in $OBJ_DIR"
else
    cd "$TESTDIR"
    Holmake -k || true
    cd ..
fi

./petr4_json_export.sh "$TESTDIR" p4include/
./petr4_to_hol4p4_dir.sh "$TESTDIR" 1
mv petr4_to_hol4p4_stf.log "$TESTDIR"

cd "$TESTDIR"
Holmake -k || true
cd ..

PASS=$(find "${TESTDIR%/}/.hol/objs" -maxdepth 1 -name '*.uo' 2>/dev/null | wc -l)
JSON_SUCCESS=$(find "$TESTDIR" -maxdepth 1 -name '*.json' -size +0c | wc -l)
SKIPPED=0
[[ -f "$EXCLUDED_LIST" ]] && SKIPPED=$(wc -l < "$EXCLUDED_LIST")

LOG="${LOG_FILE:-${TESTDIR%/}.log}"

./collect-stat.sh "$TESTDIR" > "$LOG"

echo "============================================="
echo "Total Tests: $TOTAL"
echo "Excluded Tests: $SKIPPED"
echo "Successful JSON outputs: $JSON_SUCCESS/$TOTAL"
echo "Pass: $PASS/$TOTAL"
echo "Individual test results can be found in $LOG"
