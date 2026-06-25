#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

SCRIPT_PATH="/home/user/feature-store-lab/ingest_features.py"

Test7() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_status "failed" "ingest_features.py not found at $SCRIPT_PATH"
        return
    fi

    SYNTAX_CHECK=$(python3 -m py_compile "$SCRIPT_PATH" 2>&1)

    if [ -z "$SYNTAX_CHECK" ]; then
        print_status "success" "ingest_features.py exists and is syntactically valid Python"
    else
        print_status "failed" "ingest_features.py has syntax errors: $SYNTAX_CHECK"
    fi
}

Test7
