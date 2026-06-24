#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test2() {

    if [ ! -f /var/tmp/account_id.txt ]; then
        print_status "failed" "Account ID not available — skipping"
        return
    fi

    ACCOUNT_ID=$(cat /var/tmp/account_id.txt)
    BUCKET_NAME="sagemaker-iris-lab-${ACCOUNT_ID}"
    REGION="us-west-2"

    ACCESS_KEY=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
    SECRET_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
    SESSION_TOKEN=$(jq -r '.SessionToken // empty' /home/user/aws_iam_creds.json)
    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    [ -n "$SESSION_TOKEN" ] && export AWS_SESSION_TOKEN="$SESSION_TOKEN"
    export AWS_DEFAULT_REGION="$REGION"

    BUCKET_CHECK=$(aws s3api head-bucket --bucket "$BUCKET_NAME" \
        --region "$REGION" 2>&1 || echo "NOT_FOUND")

    if echo "$BUCKET_CHECK" | grep -q "NOT_FOUND"; then
        print_status "failed" "S3 bucket not found: $BUCKET_NAME"
        return
    fi

    echo "$BUCKET_NAME" > /var/tmp/bucket_name.txt
    print_status "success" "S3 bucket exists: $BUCKET_NAME"
}

Test2
