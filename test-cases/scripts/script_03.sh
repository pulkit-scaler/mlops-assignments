#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"
GROUP_NAME="iris-model-group"

Test3() {
    # List all model packages in the group
    RESULT=$(aws sagemaker list-model-packages \
        --model-package-group-name "$GROUP_NAME" \
        --region "$REGION" \
        --no-cli-pager 2>/dev/null)

    if [ -z "$RESULT" ]; then
        print_status "failed" "Could not list model packages for '$GROUP_NAME'"
        return
    fi

    COUNT=$(echo "$RESULT" | jq '.ModelPackageSummaryList | length')
    if [ "$COUNT" -lt 1 ]; then
        print_status "failed" "No model packages found in '$GROUP_NAME' — share your Canvas model first"
        return
    fi

    # Save list for later tests
    echo "$RESULT" > /var/tmp/model_packages_list.json

    # Look for a model package with a non-sklearn container image
    # Canvas uses AutoML containers (e.g. autogluon, autopilot, xgboost)
    # which are distinct from the sagemaker-scikit-learn container
    CANVAS_FOUND="false"
    CANVAS_ARN=""

    for ARN in $(echo "$RESULT" | jq -r '.ModelPackageSummaryList[].ModelPackageArn'); do
        DETAIL=$(aws sagemaker describe-model-package \
            --model-package-name "$ARN" \
            --region "$REGION" \
            --no-cli-pager 2>/dev/null)

        if [ -z "$DETAIL" ]; then
            continue
        fi

        IMAGE=$(echo "$DETAIL" | jq -r '.InferenceSpecification.Containers[0].Image // empty')

        # Canvas models use AutoML containers, NOT sagemaker-scikit-learn
        if [ -n "$IMAGE" ] && ! echo "$IMAGE" | grep -q "sagemaker-scikit-learn"; then
            CANVAS_FOUND="true"
            CANVAS_ARN="$ARN"
            # Save the Canvas model detail for reference
            echo "$DETAIL" > /var/tmp/canvas_model_detail.json
            echo "$CANVAS_ARN" > /var/tmp/canvas_model_arn.txt
            break
        fi
    done

    if [ "$CANVAS_FOUND" = "true" ]; then
        print_status "success" "Canvas-originated model found in '$GROUP_NAME'"
    else
        print_status "failed" "No Canvas model found — all models use sagemaker-scikit-learn. Share your Canvas model to '$GROUP_NAME' via the Canvas UI"
    fi
}

Test3
