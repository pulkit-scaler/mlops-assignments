#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDS_FILE="/home/user/aws_iam_creds.json"
REGION="us-west-2"

Test6() {
    if [ ! -f /var/tmp/feature_group.json ]; then
        print_status "failed" "Feature group info not found — script_02 may have failed"
        return
    fi

    if [ ! -f "$CREDS_FILE" ]; then
        print_status "failed" "Missing aws_iam_creds.json"
        return
    fi

    export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' "$CREDS_FILE")
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' "$CREDS_FILE")
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' "$CREDS_FILE")
    if [ -n "$SESSION_TOKEN" ]; then export AWS_SESSION_TOKEN="$SESSION_TOKEN"; fi

    ACCOUNT_ID=""
    if [ -f /var/tmp/account_id.txt ]; then
        ACCOUNT_ID=$(cat /var/tmp/account_id.txt | tr -d ' \n\r')
    fi
    if [ -z "$ACCOUNT_ID" ]; then
        ACCOUNT_ID=$(aws sts get-caller-identity --region "$REGION" --query Account --output text 2>/dev/null || echo "")
    fi

    EXPECTED_BUCKET="feature-store-lab-${ACCOUNT_ID}"
    CONFIGURED_URI=$(jq -r '.OfflineStoreConfig.S3StorageConfig.S3Uri // empty' /var/tmp/feature_group.json)

    if [ -z "$CONFIGURED_URI" ]; then
        print_status "failed" "Offline store is not configured — no S3Uri found in feature group"
        return
    fi

    CONFIGURED_BUCKET=$(echo "$CONFIGURED_URI" | sed 's|s3://||' | cut -d'/' -f1)

    if [ "$CONFIGURED_BUCKET" = "$EXPECTED_BUCKET" ]; then
        print_status "success" "Offline store S3 URI uses the correct bucket ($EXPECTED_BUCKET)"
    else
        print_status "failed" "Offline store bucket is '$CONFIGURED_BUCKET' (expected '$EXPECTED_BUCKET')"
    fi
}

Test6
