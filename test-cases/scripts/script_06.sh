#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"

Test6() {
    DETAIL=""
    if [ -f "/var/tmp/sklearn_model_detail.json" ]; then
        DETAIL=$(cat /var/tmp/sklearn_model_detail.json 2>/dev/null)
    fi

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

    # Check SupportedContentTypes
    CONTENT_TYPES_COUNT=$(echo "$DETAIL" | jq '.InferenceSpecification.SupportedContentTypes | length // 0')
    if [ "$CONTENT_TYPES_COUNT" -lt 1 ]; then
        print_status "failed" "boto3 model has no SupportedContentTypes in inference spec"
        return
    fi

    # Check SupportedResponseMIMETypes
    MIME_TYPES_COUNT=$(echo "$DETAIL" | jq '.InferenceSpecification.SupportedResponseMIMETypes | length // 0')
    if [ "$MIME_TYPES_COUNT" -lt 1 ]; then
        print_status "failed" "boto3 model has no SupportedResponseMIMETypes in inference spec"
        return
    fi

    # Check SupportedRealtimeInferenceInstanceTypes
    RT_INSTANCES_COUNT=$(echo "$DETAIL" | jq '.InferenceSpecification.SupportedRealtimeInferenceInstanceTypes | length // 0')
    if [ "$RT_INSTANCES_COUNT" -lt 1 ]; then
        print_status "failed" "boto3 model has no SupportedRealtimeInferenceInstanceTypes"
        return
    fi

    # Check SupportedTransformInstanceTypes
    TRANSFORM_INSTANCES_COUNT=$(echo "$DETAIL" | jq '.InferenceSpecification.SupportedTransformInstanceTypes | length // 0')
    if [ "$TRANSFORM_INSTANCES_COUNT" -lt 1 ]; then
        print_status "failed" "boto3 model has no SupportedTransformInstanceTypes"
        return
    fi

    print_status "success" "boto3 model has content types, MIME types, and instance types configured"
}

Test6
