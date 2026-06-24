#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test8() {

    if [ ! -f /var/tmp/processed_iris.csv ]; then
        print_status "failed" "Processed CSV not available — skipping"
        return
    fi

    HEADER=$(head -n1 /var/tmp/processed_iris.csv)

    HAS_SEPAL_LEN=false
    HAS_SEPAL_WID=false
    HAS_PETAL_LEN=false
    HAS_PETAL_WID=false

    echo "$HEADER" | grep -qi "sepal_length" && HAS_SEPAL_LEN=true
    echo "$HEADER" | grep -qi "sepal_width"  && HAS_SEPAL_WID=true
    echo "$HEADER" | grep -qi "petal_length" && HAS_PETAL_LEN=true
    echo "$HEADER" | grep -qi "petal_width"  && HAS_PETAL_WID=true

    if $HAS_SEPAL_LEN && $HAS_SEPAL_WID && $HAS_PETAL_LEN && $HAS_PETAL_WID; then
        # Spot-check that values in sepal_length are numeric floats
        SAMPLE=$(tail -n +2 /var/tmp/processed_iris.csv | head -5 | cut -d',' -f1 | tr -d '\r')
        NON_FLOAT=$(echo "$SAMPLE" | grep -v '^[0-9][0-9]*\.[0-9][0-9]*$' || true)
        if [ -z "$NON_FLOAT" ]; then
            print_status "success" "All 4 feature columns present with valid float values: sepal_length, sepal_width, petal_length, petal_width"
        else
            print_status "failed" "Feature columns present but sepal_length contains unexpected values: $NON_FLOAT"
        fi
    else
        MISSING=""
        $HAS_SEPAL_LEN || MISSING="$MISSING [sepal_length]"
        $HAS_SEPAL_WID || MISSING="$MISSING [sepal_width]"
        $HAS_PETAL_LEN || MISSING="$MISSING [petal_length]"
        $HAS_PETAL_WID || MISSING="$MISSING [petal_width]"
        print_status "failed" "Missing feature columns:$MISSING (header: $HEADER)"
    fi
}

Test8
