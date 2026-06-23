#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test10() {

    if [ ! -f /home/user/aws_iam_creds.json ]; then
        print_status "failed" "AWS IAM credentials file not found"
        return
    fi

    AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId // .aws_access_key_id // empty' /home/user/aws_iam_creds.json)
    AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey // .aws_secret_access_key // empty' /home/user/aws_iam_creds.json)
    AWS_REGION="us-west-2"

    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        print_status "failed" "Could not read AWS credentials"
        return
    fi

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION="$AWS_REGION"

    API_IMAGES=$(aws ecr list-images --repository-name mlops-api --region "$AWS_REGION" --query 'imageIds[*].imageTag' --output text 2>/dev/null)
    API_OK=false
    if [ -n "$API_IMAGES" ] && [ "$API_IMAGES" != "None" ]; then
        API_OK=true
    fi

    DASHBOARD_IMAGES=$(aws ecr list-images --repository-name mlops-dashboard --region "$AWS_REGION" --query 'imageIds[*].imageTag' --output text 2>/dev/null)
    DASHBOARD_OK=false
    if [ -n "$DASHBOARD_IMAGES" ] && [ "$DASHBOARD_IMAGES" != "None" ]; then
        DASHBOARD_OK=true
    fi

    if $API_OK && $DASHBOARD_OK; then
        print_status "success" "ECR images found for both mlops-api and mlops-dashboard"
    else
        MISSING=""
        $API_OK || MISSING="$MISSING mlops-api"
        $DASHBOARD_OK || MISSING="$MISSING mlops-dashboard"
        print_status "failed" "ECR images missing for:$MISSING"
    fi
}

Test10
