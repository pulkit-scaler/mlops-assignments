#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test6() {

    if [ ! -f /var/tmp/processed_iris.csv ]; then
        print_status "failed" "Processed CSV not available — skipping"
        return
    fi

    # Find the column index of 'target'
    HEADER=$(head -n1 /var/tmp/processed_iris.csv)
    TARGET_COL=$(echo "$HEADER" | tr ',' '\n' | grep -ni "target" | cut -d: -f1)

    if [ -z "$TARGET_COL" ]; then
        print_status "failed" "No 'target' column found — run Test5 first"
        return
    fi

    # Extract all values in the target column (skip header)
    TARGET_VALUES=$(tail -n +2 /var/tmp/processed_iris.csv \
        | cut -d',' -f"$TARGET_COL" \
        | tr -d '\r' \
        | sort -u)

    # Check that all unique values are numeric (0.0, 1.0, 2.0 or 0, 1, 2)
    NON_NUMERIC=$(echo "$TARGET_VALUES" | grep -v '^[0-9][0-9]*\.[0-9][0-9]*$' || true)
    UNIQUE_COUNT=$(echo "$TARGET_VALUES" | wc -l | tr -d ' ')

    if [ -z "$NON_NUMERIC" ] && [ "$UNIQUE_COUNT" -eq 3 ]; then
        print_status "success" "Ordinal encode applied: target column contains $UNIQUE_COUNT numeric classes ($(echo "$TARGET_VALUES" | tr '\n' ' '))"
    elif [ -n "$NON_NUMERIC" ]; then
        print_status "failed" "Target column contains non-numeric values ($NON_NUMERIC) — encode categorical transform was not applied"
    else
        print_status "failed" "Target column has $UNIQUE_COUNT unique value(s) — expected exactly 3 (one per Iris class). Values: $(echo "$TARGET_VALUES" | tr '\n' ' ')"
    fi
}

Test6
