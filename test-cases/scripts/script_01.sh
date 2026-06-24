#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test1() {

    CREDENTIALS_FILE="/home/user/aws_iam_creds.json"

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        print_status "failed" "Missing aws_iam_creds.json at /home/user/aws_iam_creds.json"
        return
    fi

    ACCESS_KEY=$(jq -r '.AccessKeyId // empty' "$CREDENTIALS_FILE")
    SECRET_KEY=$(jq -r '.SecretAccessKey // empty' "$CREDENTIALS_FILE")

    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        print_status "failed" "aws_iam_creds.json is missing AccessKeyId or SecretAccessKey"
        return
    fi

    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' "$CREDENTIALS_FILE")
    [ -n "$SESSION_TOKEN" ] && export AWS_SESSION_TOKEN="$SESSION_TOKEN"
    export AWS_DEFAULT_REGION="us-west-2"

    CALLER=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

    if [ -n "$CALLER" ] && [ "$CALLER" != "None" ]; then
        echo "$CALLER" > /var/tmp/account_id.txt
        print_status "success" "AWS credentials valid (Account: $CALLER)"
    else
        print_status "failed" "AWS credentials in aws_iam_creds.json are invalid or expired"
    fi
}

Test1
