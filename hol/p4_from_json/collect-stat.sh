#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$1"

if [[ -z "$TARGET_DIR" ]]; then
    echo "Error: No directory provided."
    echo "Usage: $0 <directory_name>"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

OBJ_DIR="$TARGET_DIR/.hol/objs"
EXCLUDED_LIST="$TARGET_DIR/.excluded_tests"

for p4_file in "$TARGET_DIR"/*.p4; do
    [[ -e "$p4_file" ]] || continue

    base_name=${p4_file##*/}
    base_name=${base_name%.p4}

    stf_file="$TARGET_DIR/$base_name.stf"

    # only process if pair exists
    [[ -f "$stf_file" ]] || continue

    theory_name=${base_name//-/_}

    if [[ -f "$OBJ_DIR/${theory_name}Theory.uo" ]]; then
        echo "[PASS] $base_name.p4"
    else
        echo "[FAIL] $base_name.p4"
    fi
done

if [[ -f "$EXCLUDED_LIST" ]]; then
    while IFS= read -r name || [[ -n "$name" ]]; do
        [[ -z "$name" ]] && continue
        echo "[SKIP] $name"
    done < "$EXCLUDED_LIST"
fi

