#!/usr/bin/env bash

# Define the target directory variable
TARGET_DIR="$1"

if [[ -z "$TARGET_DIR" ]]; then
    echo "Error: No directory provided."
    echo "Usage: $0 <directory_name> (e.g., $0 v1model)"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

# Derived paths based on HOL4's standard directory structure
OBJ_DIR="$TARGET_DIR/.hol/objs"

# echo "Checking for compiled .uo files in $OBJ_DIR..."
# echo "-------------------------------------------"

# Loop through all .p4 files in the target directory
for p4_file in "$TARGET_DIR"/*.p4; do
    # Get the base filename (e.g., "arith-bmv2" from "v1model/arith-bmv2.p4")
    # We also need to handle the fact that HOL4 usually names theories
    # by replacing hyphens with underscores.
    base_name=$(basename "$p4_file" .p4)
    theory_name=$(echo "$base_name" | tr '-' '_')

    # Check for the existence of the .uo file
    # Note: HOL4 appends 'Theory' to the generated filename
    if [[ -f "$OBJ_DIR/${theory_name}Theory.uo" ]]; then
        echo "[PASS] $base_name.p4"
    else
        echo "[FAIL] $base_name.p4"
    fi
done
