#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test9() {

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

    PROCESSED_FILES=$(aws s3 ls "s3://${BUCKET_NAME}/processed-data/" \
        --recursive --region "$REGION" 2>/dev/null | grep -i "\.csv" | wc -l | tr -d ' ' || echo "0")

    if [ "$PROCESSED_FILES" -eq 0 ]; then
        print_status "failed" "No processed CSV found under s3://$BUCKET_NAME/processed-data/ — export your flow output using 'Export to S3' in Data Wrangler and wait for the Processing Job to complete"
        return
    fi

    FIRST_CSV=$(aws s3 ls "s3://${BUCKET_NAME}/processed-data/" \
        --recursive --region "$REGION" 2>/dev/null | grep -i "\.csv" | head -n1 | awk '{print $4}')

    echo "$FIRST_CSV" > /var/tmp/processed_csv_key.txt
    print_status "success" "Processed output CSV found: s3://$BUCKET_NAME/$FIRST_CSV ($PROCESSED_FILES file(s))"
}

Test9
