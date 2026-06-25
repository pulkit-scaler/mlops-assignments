#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"
GROUP_NAME="iris-model-group"

Test4() {
    # List all model packages in the group
    RESULT=""
    if [ -f "/var/tmp/model_packages_list.json" ]; then
        RESULT=$(cat /var/tmp/model_packages_list.json 2>/dev/null)
    fi
    if [ -z "$RESULT" ]; then
        RESULT=$(aws sagemaker list-model-packages \
            --model-package-group-name "$GROUP_NAME" \
            --region "$REGION" \
            --no-cli-pager 2>/dev/null)
    fi

    if [ -z "$RESULT" ]; then
        print_status "failed" "Could not list model packages for '$GROUP_NAME'"
        return
    fi

    COUNT=$(echo "$RESULT" | jq '.ModelPackageSummaryList | length')
    if [ "$COUNT" -lt 1 ]; then
        print_status "failed" "No model packages found in '$GROUP_NAME'"
        return
    fi

    # Look for a model package with a sagemaker-scikit-learn container
    SKLEARN_FOUND="false"
    SKLEARN_ARN=""

    for ARN in $(echo "$RESULT" | jq -r '.ModelPackageSummaryList[].ModelPackageArn'); do
        DETAIL=$(aws sagemaker describe-model-package \
            --model-package-name "$ARN" \
            --region "$REGION" \
            --no-cli-pager 2>/dev/null)

        if [ -z "$DETAIL" ]; then
            continue
        fi

        IMAGE=$(echo "$DETAIL" | jq -r '.InferenceSpecification.Containers[0].Image // empty')

        if [ -n "$IMAGE" ] && echo "$IMAGE" | grep -q "sagemaker-scikit-learn"; then
            SKLEARN_FOUND="true"
            SKLEARN_ARN="$ARN"
            echo "$DETAIL" > /var/tmp/sklearn_model_detail.json
            echo "$SKLEARN_ARN" > /var/tmp/sklearn_model_arn.txt
            break
        fi
    done

    if [ "$SKLEARN_FOUND" = "true" ]; then
        print_status "success" "boto3-registered model with sklearn container found"
    else
        print_status "failed" "No model with sagemaker-scikit-learn container found — run your register_model.py script"
    fi
}

Test4
