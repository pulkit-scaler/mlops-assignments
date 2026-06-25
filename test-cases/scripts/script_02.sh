#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"
GROUP_NAME="iris-model-group"

Test2() {
    RESULT=$(aws sagemaker describe-model-package-group \
        --model-package-group-name "$GROUP_NAME" \
        --region "$REGION" \
        --no-cli-pager 2>/dev/null)

    if [ -z "$RESULT" ]; then
        print_status "failed" "Model Package Group '$GROUP_NAME' does not exist"
        return
    fi

    STATUS=$(echo "$RESULT" | jq -r '.ModelPackageGroupStatus // empty')

    if [ "$STATUS" = "Completed" ]; then
        echo "$RESULT" > /var/tmp/model_package_group.json
        print_status "success" "Model Package Group '$GROUP_NAME' exists (status: Completed)"
    elif [ -n "$STATUS" ]; then
        print_status "failed" "Model Package Group exists but status is '$STATUS' (expected Completed)"
    else
        print_status "failed" "Model Package Group '$GROUP_NAME' does not exist"
    fi
}

Test2
