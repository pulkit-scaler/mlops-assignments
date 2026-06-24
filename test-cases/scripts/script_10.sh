#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test10() {

    if [ ! -f /var/tmp/bucket_name.txt ] || [ ! -f /var/tmp/processed_csv_key.txt ]; then
        print_status "failed" "Processed CSV location not available — skipping"
        return
    fi

    BUCKET_NAME=$(cat /var/tmp/bucket_name.txt)
    CSV_KEY=$(cat /var/tmp/processed_csv_key.txt)
    REGION="us-west-2"

    ACCESS_KEY=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
    SECRET_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' /home/user/aws_iam_creds.json)
    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    [ -n "$SESSION_TOKEN" ] && export AWS_SESSION_TOKEN="$SESSION_TOKEN"
    export AWS_DEFAULT_REGION="$REGION"

    aws s3 cp "s3://${BUCKET_NAME}/${CSV_KEY}" /var/tmp/processed_iris.csv \
        --region "$REGION" > /dev/null 2>&1

    if [ ! -f /var/tmp/processed_iris.csv ]; then
        print_status "failed" "Could not download processed CSV for validation"
        return
    fi

    # Row count — Iris has no missing values so drop-missing retains all 150 rows
    ROW_COUNT=$(tail -n +2 /var/tmp/processed_iris.csv | wc -l | tr -d ' ')

    if [ "$ROW_COUNT" -lt 140 ]; then
        print_status "failed" "Processed CSV has only $ROW_COUNT rows — expected at least 140"
        return
    fi

    HEADER=$(head -n1 /var/tmp/processed_iris.csv)

    HAS_SEPAL=false
    HAS_PETAL=false
    HAS_TARGET=false

    echo "$HEADER" | grep -qi "sepal"                                           && HAS_SEPAL=true
    echo "$HEADER" | grep -qi "petal"                                           && HAS_PETAL=true
    echo "$HEADER" | grep -qi "target\|species\|setosa\|versicolor\|virginica"  && HAS_TARGET=true

    if $HAS_SEPAL && $HAS_PETAL && $HAS_TARGET; then
        print_status "success" "Processed CSV valid: $ROW_COUNT rows, correct columns present"
    else
        MISSING=""
        $HAS_SEPAL   || MISSING="$MISSING [sepal columns missing]"
        $HAS_PETAL   || MISSING="$MISSING [petal columns missing]"
        $HAS_TARGET  || MISSING="$MISSING [target/species column missing]"
        print_status "failed" "Processed CSV column validation failed:$MISSING (header: $HEADER)"
    fi
}

Test10
