#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDS_FILE="/home/user/aws_iam_creds.json"

Test1() {
    if [ ! -f "$CREDS_FILE" ]; then
        print_status "failed" "Missing /home/user/aws_iam_creds.json"
        return
    fi

    ACCESS_KEY=$(jq -r '.AccessKeyId // empty' "$CREDS_FILE")
    SECRET_KEY=$(jq -r '.SecretAccessKey // empty' "$CREDS_FILE")

    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        print_status "failed" "aws_iam_creds.json is missing AccessKeyId or SecretAccessKey"
        return
    fi

    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' "$CREDS_FILE")
    if [ -n "$SESSION_TOKEN" ]; then
        export AWS_SESSION_TOKEN="$SESSION_TOKEN"
    fi

    CALLER=$(aws sts get-caller-identity --region us-west-2 --query Account --output text 2>/dev/null || echo "")

    if [ -n "$CALLER" ]; then
        echo "$CALLER" > /var/tmp/account_id.txt
        print_status "success" "AWS credentials valid — account: $CALLER"
    else
        print_status "failed" "AWS credentials are invalid or expired"
    fi
}

Test1
