#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"
GROUP_NAME="iris-model-group"

Test10() {
    RESULT=$(aws sagemaker list-model-packages \
        --model-package-group-name "$GROUP_NAME" \
        --region "$REGION" \
        --no-cli-pager 2>/dev/null)

    if [ -z "$RESULT" ]; then
        print_status "failed" "Could not list model packages for '$GROUP_NAME'"
        return
    fi

    COUNT=$(echo "$RESULT" | jq '.ModelPackageSummaryList | length')

    if [ "$COUNT" -ge 2 ]; then
        VERSIONS=$(echo "$RESULT" | jq -r '.ModelPackageSummaryList[].ModelPackageVersion' | sort -n | tr '\n' ',' | sed 's/,$//')
        print_status "success" "Found $COUNT model package versions (versions: $VERSIONS)"
    elif [ "$COUNT" -eq 1 ]; then
        print_status "failed" "Only 1 model package version found — need at least 2 (Canvas + boto3)"
    else
        print_status "failed" "No model package versions found in '$GROUP_NAME'"
    fi
}

Test10
