#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/scripts/wb-lib"

echo "1: Parsing flags"
wb_parse_output_flags "$@"
echo "2: Setting args"
set -- "${WB_REMAINING_ARGS[@]}"
echo "3: Arg count: $#"
echo "4: First arg: ${1:-NONE}"
echo "5: Output format: $WB_OUTPUT_FORMAT"
