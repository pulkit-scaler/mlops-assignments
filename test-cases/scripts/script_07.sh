#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"
GROUP_NAME="iris-model-group"

Test7() {
    # Re-fetch to get current approval statuses
    RESULT=$(aws sagemaker list-model-packages \
        --model-package-group-name "$GROUP_NAME" \
        --region "$REGION" \
        --no-cli-pager 2>/dev/null)

    if [ -z "$RESULT" ]; then
        print_status "failed" "Could not list model packages for '$GROUP_NAME'"
        return
    fi

    APPROVED_COUNT=$(echo "$RESULT" | jq '[.ModelPackageSummaryList[] | select(.ModelApprovalStatus == "Approved")] | length')

    if [ "$APPROVED_COUNT" -ge 1 ]; then
        print_status "success" "Found $APPROVED_COUNT model package(s) with Approved status"
    else
        STATUSES=$(echo "$RESULT" | jq -r '.ModelPackageSummaryList[].ModelApprovalStatus' | sort | uniq | tr '\n' ', ' | sed 's/,$//')
        print_status "failed" "No model packages with Approved status (found statuses: $STATUSES)"
    fi
}

Test7
