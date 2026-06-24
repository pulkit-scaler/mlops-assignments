#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test3() {

    if [ ! -f /var/tmp/bucket_name.txt ]; then
        print_status "failed" "Bucket name not available — skipping"
        return
    fi

    BUCKET_NAME=$(cat /var/tmp/bucket_name.txt)
    REGION="us-west-2"

    ACCESS_KEY=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
    SECRET_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' /home/user/aws_iam_creds.json)
    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    [ -n "$SESSION_TOKEN" ] && export AWS_SESSION_TOKEN="$SESSION_TOKEN"
    export AWS_DEFAULT_REGION="$REGION"

    RAW_CHECK=$(aws s3api head-object \
        --bucket "$BUCKET_NAME" --key "raw-data/iris_raw.csv" \
        --region "$REGION" 2>&1 || echo "NOT_FOUND")

    if echo "$RAW_CHECK" | grep -q "NOT_FOUND"; then
        print_status "failed" "Raw dataset not found at s3://$BUCKET_NAME/raw-data/iris_raw.csv"
        return
    fi

    FILE_SIZE=$(aws s3api head-object \
        --bucket "$BUCKET_NAME" --key "raw-data/iris_raw.csv" \
        --region "$REGION" --query 'ContentLength' --output text 2>/dev/null || echo "0")

    if [ "$FILE_SIZE" -lt 2000 ]; then
        print_status "failed" "iris_raw.csv found but too small ($FILE_SIZE bytes) — may be corrupt"
        return
    fi

    print_status "success" "Raw Iris dataset found at s3://$BUCKET_NAME/raw-data/iris_raw.csv ($FILE_SIZE bytes)"
}

Test3
