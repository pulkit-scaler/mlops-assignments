#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test5() {

    if [ ! -f /var/tmp/processed_iris.csv ]; then
        print_status "failed" "Processed CSV not available — skipping"
        return
    fi

    HEADER=$(head -n1 /var/tmp/processed_iris.csv)

    HAS_TARGET=false
    HAS_SPECIES=false

    echo "$HEADER" | grep -qi "target"  && HAS_TARGET=true
    echo "$HEADER" | grep -qi "species" && HAS_SPECIES=true

    if $HAS_TARGET && ! $HAS_SPECIES; then
        print_status "success" "Rename transform applied: 'species' column renamed to 'target'"
    elif ! $HAS_TARGET && ! $HAS_SPECIES; then
        print_status "failed" "Neither 'target' nor 'species' found in header — rename column transform may not have been applied (header: $HEADER)"
    elif $HAS_SPECIES && ! $HAS_TARGET; then
        print_status "failed" "Column still named 'species' — rename column transform was not applied"
    else
        print_status "failed" "Both 'target' and 'species' found in header — unexpected column state (header: $HEADER)"
    fi
}

Test5
