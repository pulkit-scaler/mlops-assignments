#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"

Test9() {
    REG_FILE="/var/tmp/registration_details.json"
    if [ ! -f "$REG_FILE" ]; then
        REG_FILE="/home/user/model-registry-lab/registration_details.json"
        if [ ! -f "$REG_FILE" ]; then
            print_status "failed" "registration_details.json not available"
            return
        fi
    fi

    # Check required fields
    GROUP_NAME=$(jq -r '.model_package_group_name // empty' "$REG_FILE")
    CANVAS_ARN=$(jq -r '.canvas_model_package_arn // empty' "$REG_FILE")
    BOTO3_ARN=$(jq -r '.boto3_model_package_arn // empty' "$REG_FILE")
    BOTO3_STATUS=$(jq -r '.boto3_approval_status // empty' "$REG_FILE")
    INF_IMAGE=$(jq -r '.inference_image // empty' "$REG_FILE")
    MODEL_URL=$(jq -r '.model_data_url // empty' "$REG_FILE")
    TOTAL_VERSIONS=$(jq -r '.total_versions // empty' "$REG_FILE")

    ERRORS=""

    if [ "$GROUP_NAME" != "iris-model-group" ]; then
        ERRORS="${ERRORS}model_package_group_name should be 'iris-model-group' (got: '$GROUP_NAME'); "
    fi

    if [ -z "$CANVAS_ARN" ] || ! echo "$CANVAS_ARN" | grep -q "arn:aws:sagemaker"; then
        ERRORS="${ERRORS}canvas_model_package_arn is missing or not a valid ARN; "
    fi

    if [ -z "$BOTO3_ARN" ] || ! echo "$BOTO3_ARN" | grep -q "arn:aws:sagemaker"; then
        ERRORS="${ERRORS}boto3_model_package_arn is missing or not a valid ARN; "
    fi

    if [ "$BOTO3_STATUS" != "Approved" ]; then
        ERRORS="${ERRORS}boto3_approval_status should be 'Approved' (got: '$BOTO3_STATUS'); "
    fi

    if [ -z "$INF_IMAGE" ]; then
        ERRORS="${ERRORS}inference_image is missing; "
    fi

    if [ -z "$MODEL_URL" ] || ! echo "$MODEL_URL" | grep -q "^s3://"; then
        ERRORS="${ERRORS}model_data_url is missing or not an S3 URI; "
    fi

    if [ -z "$TOTAL_VERSIONS" ] || [ "$TOTAL_VERSIONS" -lt 2 ] 2>/dev/null; then
        ERRORS="${ERRORS}total_versions should be >= 2 (got: '$TOTAL_VERSIONS'); "
    fi

    # Spot-check: verify the boto3 ARN resolves in AWS
    if [ -n "$BOTO3_ARN" ] && echo "$BOTO3_ARN" | grep -q "arn:aws:sagemaker"; then
        CHECK=$(aws sagemaker describe-model-package \
            --model-package-name "$BOTO3_ARN" \
            --region "$REGION" \
            --query 'ModelPackageArn' \
            --output text \
            --no-cli-pager 2>/dev/null || echo "")
        if [ -z "$CHECK" ]; then
            ERRORS="${ERRORS}boto3_model_package_arn does not resolve to a real model package; "
        fi
    fi

    # Spot-check: verify the Canvas ARN resolves in AWS
    if [ -n "$CANVAS_ARN" ] && echo "$CANVAS_ARN" | grep -q "arn:aws:sagemaker"; then
        CHECK=$(aws sagemaker describe-model-package \
            --model-package-name "$CANVAS_ARN" \
            --region "$REGION" \
            --query 'ModelPackageArn' \
            --output text \
            --no-cli-pager 2>/dev/null || echo "")
        if [ -z "$CHECK" ]; then
            ERRORS="${ERRORS}canvas_model_package_arn does not resolve to a real model package; "
        fi
    fi

    if [ -z "$ERRORS" ]; then
        print_status "success" "registration_details.json has all required fields with valid values"
    else
        print_status "failed" "registration_details.json issues: $ERRORS"
    fi
}

Test9
