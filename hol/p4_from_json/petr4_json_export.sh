#!/usr/bin/env bash
#This script is used to transform .p4 programs to a .json representation using petr4.
set -u

EXAMPLES_PATH="$1"
P4_INCLUDE="$2"
JOBS="${3:-4}"

find "$EXAMPLES_PATH" -maxdepth 1 -type f -name '*.p4' -print0 \
| xargs -0 -P "$JOBS" -I {} \
  sh -c 'petr4 typecheck -json -I "$1" "$2" > "${2%.p4}.json"' _ "$P4_INCLUDE" "{}"
