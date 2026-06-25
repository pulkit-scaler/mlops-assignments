#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDS_FILE="/home/user/aws_iam_creds.json"
REGION="us-west-2"

_setup_creds() {
    export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' "$CREDS_FILE")
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' "$CREDS_FILE")
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' "$CREDS_FILE")
    if [ -n "$SESSION_TOKEN" ]; then export AWS_SESSION_TOKEN="$SESSION_TOKEN"; fi
}

Test10() {
    if [ ! -f "$CREDS_FILE" ]; then
        print_status "failed" "Missing aws_iam_creds.json"
        return
    fi

    _setup_creds

    ACCOUNT_ID=""
    if [ -f /var/tmp/account_id.txt ]; then
        ACCOUNT_ID=$(cat /var/tmp/account_id.txt | tr -d ' \n\r')
    fi
    if [ -z "$ACCOUNT_ID" ]; then
        ACCOUNT_ID=$(aws sts get-caller-identity --region "$REGION" --query Account --output text 2>/dev/null || echo "")
    fi

    S3_BUCKET="feature-store-lab-${ACCOUNT_ID}"

    # Search broadly — SageMaker appends a timestamp to the feature group name
    # so the path is offline-store/iris-features-<timestamp>/data/ not iris-features/data/
    FILES=$(aws s3 ls "s3://${S3_BUCKET}/feature-store/" \
        --recursive \
        --region "$REGION" \
        --no-cli-pager 2>/dev/null \
        | grep "offline-store/iris-features" \
        | grep "\.parquet" \
        | wc -l | tr -d ' ')

    if [ "$FILES" -gt "0" ]; then
        print_status "success" "Offline store has data — ingestion confirmed ($FILES parquet file(s) in S3)"
    else
        print_status "failed" "No parquet files found in offline store — run ingest_features.py and wait 15 minutes before submitting"
    fi
}

Test10
