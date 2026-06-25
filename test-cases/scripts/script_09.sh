#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

OUTPUT_FILE="/home/user/feature-store-lab/retrieved_records.json"
EXPECTED_COUNT=20

Test9() {
    if [ ! -f "$OUTPUT_FILE" ]; then
        print_status "failed" "retrieved_records.json not found — run ingest_features.py first"
        return
    fi

    if ! jq empty "$OUTPUT_FILE" 2>/dev/null; then
        print_status "failed" "retrieved_records.json is not valid JSON"
        return
    fi

    IS_ARRAY=$(jq 'if type == "array" then "yes" else "no" end' "$OUTPUT_FILE" 2>/dev/null)
    HAS_RECORDS_KEY=$(jq 'if type == "object" and has("records") then "yes" else "no" end' "$OUTPUT_FILE" 2>/dev/null)

    if [ "$IS_ARRAY" = '"yes"' ]; then
        FIRST=$(jq '.[0]' "$OUTPUT_FILE")
        ACTUAL=$(jq 'length' "$OUTPUT_FILE" | tr -d ' \n\r')
    elif [ "$HAS_RECORDS_KEY" = '"yes"' ]; then
        FIRST=$(jq '.records[0]' "$OUTPUT_FILE")
        ACTUAL=$(jq '.records | length' "$OUTPUT_FILE" | tr -d ' \n\r')
    else
        print_status "failed" "retrieved_records.json must be a JSON array or object with a 'records' key"
        return
    fi

    MISSING=""
    for field in record_id sepal_length sepal_width petal_length petal_width species; do
        HAS=$(echo "$FIRST" | jq --arg f "$field" 'has($f)' 2>/dev/null)
        if [ "$HAS" != "true" ]; then
            MISSING="$MISSING $field"
        fi
    done

    if [ -n "$MISSING" ]; then
        print_status "failed" "retrieved_records.json records are missing fields:$MISSING"
        return
    fi

    if [ "$ACTUAL" -ge "$EXPECTED_COUNT" ]; then
        print_status "success" "retrieved_records.json has $ACTUAL records with all expected fields"
    else
        print_status "failed" "retrieved_records.json has $ACTUAL records (expected $EXPECTED_COUNT)"
    fi
}

Test9
