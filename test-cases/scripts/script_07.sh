#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test7() {

    if [ ! -f /var/tmp/processed_iris.csv ]; then
        print_status "failed" "Processed CSV not available — skipping"
        return
    fi

    ROW_COUNT=$(tail -n +2 /var/tmp/processed_iris.csv | wc -l | tr -d ' ')

    if [ "$ROW_COUNT" -eq 150 ]; then
        print_status "success" "Row count correct: $ROW_COUNT rows — all Iris records retained after handle missing transform"
    elif [ "$ROW_COUNT" -ge 140 ]; then
        print_status "failed" "Row count is $ROW_COUNT — expected exactly 150. The Iris dataset has no missing values so handle missing should retain all rows. Check that drop missing was applied only to numeric columns."
    else
        print_status "failed" "Row count is only $ROW_COUNT — expected 150. Too many rows dropped. Make sure handle missing was applied only to the 4 numeric columns, not 'species'/'target'."
    fi
}

Test7
