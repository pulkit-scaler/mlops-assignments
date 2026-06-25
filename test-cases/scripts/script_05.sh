#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"

Test5() {
    # Read the lab env to get the expected S3 bucket
    S3_BUCKET=""
    if [ -f "/home/user/lab_env.txt" ]; then
        S3_BUCKET=$(grep 'S3_BUCKET=' /home/user/lab_env.txt | cut -d= -f2 | tr -d '\r')
    fi

    # Get the sklearn model detail (saved by test 04)
    DETAIL=""
    if [ -f "/var/tmp/sklearn_model_detail.json" ]; then
        DETAIL=$(cat /var/tmp/sklearn_model_detail.json 2>/dev/null)
    fi

    # Fallback: try to find the sklearn model ourselves
    if [ -z "$DETAIL" ]; then
        SKLEARN_ARN=""
        if [ -f "/var/tmp/sklearn_model_arn.txt" ]; then
            SKLEARN_ARN=$(cat /var/tmp/sklearn_model_arn.txt 2>/dev/null | tr -d '\n\r ')
        fi
        if [ -n "$SKLEARN_ARN" ]; then
            DETAIL=$(aws sagemaker describe-model-package \
                --model-package-name "$SKLEARN_ARN" \
                --region "$REGION" \
                --no-cli-pager 2>/dev/null)
        fi
    fi

    if [ -z "$DETAIL" ]; then
        print_status "failed" "No sklearn model package detail available — previous test may have failed"
        return
    fi

    MODEL_DATA_URL=$(echo "$DETAIL" | jq -r '.InferenceSpecification.Containers[0].ModelDataUrl // empty')

    if [ -z "$MODEL_DATA_URL" ]; then
        print_status "failed" "boto3 model has no ModelDataUrl in inference specification"
        return
    fi

    # Verify it points to the correct S3 artifact
    if echo "$MODEL_DATA_URL" | grep -q "s3://.*models/iris-model.tar.gz"; then
        print_status "success" "Model data URL points to correct S3 artifact"
    elif [ -n "$S3_BUCKET" ] && echo "$MODEL_DATA_URL" | grep -q "$S3_BUCKET"; then
        print_status "success" "Model data URL points to lab S3 bucket artifact"
    else
        print_status "failed" "Model data URL points to unexpected location: $MODEL_DATA_URL"
    fi
}

Test5
