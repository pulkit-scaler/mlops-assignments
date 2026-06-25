#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDS_FILE="/home/user/aws_iam_creds.json"
FEATURE_GROUP_NAME="iris-features"
REGION="us-west-2"

_setup_creds() {
    export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' "$CREDS_FILE")
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' "$CREDS_FILE")
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' "$CREDS_FILE")
    if [ -n "$SESSION_TOKEN" ]; then export AWS_SESSION_TOKEN="$SESSION_TOKEN"; fi
}

Test2() {
    if [ ! -f "$CREDS_FILE" ]; then
        print_status "failed" "Missing aws_iam_creds.json — cannot verify feature group"
        return
    fi

    _setup_creds

    FG_INFO=$(aws sagemaker describe-feature-group \
        --feature-group-name "$FEATURE_GROUP_NAME" \
        --region "$REGION" \
        --output json 2>/dev/null || echo "")

    if [ -z "$FG_INFO" ]; then
        print_status "failed" "Feature group '$FEATURE_GROUP_NAME' does not exist — create it using the AWS CLI first"
        return
    fi

    echo "$FG_INFO" > /var/tmp/feature_group.json
    print_status "success" "Feature group '$FEATURE_GROUP_NAME' exists"
}

Test2
