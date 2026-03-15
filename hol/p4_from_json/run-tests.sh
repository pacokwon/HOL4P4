#!/usr/bin/env bash

EXCLUDE_FILES=()
LOG_FILE=""
JOBS=""

while getopts "e:o:j:" opt; do
  case "$opt" in
    e) EXCLUDE_FILES+=("$OPTARG") ;;
    o) LOG_FILE="$OPTARG" ;;
    j) JOBS="$OPTARG" ;;
    *) echo "Usage: $0 [-e exclude_file ...] [-o logfile] [-j jobs] testdir"; exit 1 ;;
  esac
done

shift $((OPTIND - 1))

# Default only if -j not provided
if [[ -z "$JOBS" ]]; then
    n=$(nproc)
    JOBS=$(( n > 1 ? n - 1 : 1 ))
fi

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

case "$TESTDIR" in
    *p4c-v1model*|*p4c-ebpf*)
        EXCLUDE_MODE="p4c"
        ;;
    *p4testgen-v1model*|*p4testgen-ebpf*)
        EXCLUDE_MODE="p4testgen"
        ;;
    *)
        echo "Error: could not determine exclude mode from TESTDIR: $TESTDIR"
        exit 1
        ;;
esac

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

exclude_exact_file() {
    local filename="$1"
    local f="$TESTDIR/$filename"

    if [[ -f "$f" ]]; then
        mv "$f" "$EXCLUDED_DIR/"
        echo "$filename" >> "$EXCLUDED_LIST"
    fi
}

exclude_p4testgen_p4_family() {
    local stem="$1"
    local f

    shopt -s nullglob
    for f in "$TESTDIR/${stem}"__*.p4; do
        [[ -f "$f" ]] || continue
        mv "$f" "$EXCLUDED_DIR/"
        echo "$(basename "$f")" >> "$EXCLUDED_LIST"
    done
    shopt -u nullglob
}

exclude_p4testgen_stf_instance() {
    local name="$1"

    if [[ "$name" =~ ^(.*)_([0-9]+)\.stf$ ]]; then
        local base="${BASH_REMATCH[1]}"
        local n="${BASH_REMATCH[2]}"
        local target="${base}__${n}.stf"
        local f="$TESTDIR/$target"

        if [[ -f "$f" ]]; then
            mv "$f" "$EXCLUDED_DIR/"
            echo "$target" >> "$EXCLUDED_LIST"
        fi
    fi
}

if [[ ${#EXCLUDE_FILES[@]} -gt 0 ]]; then
    mkdir -p "$EXCLUDED_DIR"
    : > "$EXCLUDED_LIST"

    for EXCLUDE_FILE in "${EXCLUDE_FILES[@]}"; do
        if [[ ! -f "$EXCLUDE_FILE" ]]; then
            echo "Error: exclude file not found: $EXCLUDE_FILE"
            exit 1
        fi

        while IFS= read -r raw || [[ -n "$raw" ]]; do
            raw="${raw#"${raw%%[![:space:]]*}"}"
            raw="${raw%"${raw##*[![:space:]]}"}"
            [[ -z "$raw" ]] && continue

	    if [[ "$raw" == *p4_16_errors* ]]; then
                continue
            fi

            name=$(basename "$raw")

            case "$EXCLUDE_MODE" in
                p4c)
                    case "$name" in
                        *.p4|*.stf)
                            exclude_exact_file "$name"
                            ;;
                    esac
                    ;;
                p4testgen)
                    case "$name" in
                        *.p4)
                            stem="${name%.p4}"
                            exclude_p4testgen_p4_family "$stem"
                            ;;
                        *.stf)
                            exclude_p4testgen_stf_instance "$name"
                            ;;
                    esac
                    ;;
            esac
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
    Holmake -j $JOBS -k || true
    cd ..
fi

./petr4_json_export.sh "$TESTDIR" p4include/
./petr4_to_hol4p4_dir.sh "$TESTDIR" $JOBS
mv petr4_to_hol4p4_stf.log "$TESTDIR"

cd "$TESTDIR"
Holmake -j $JOBS -k || true
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
