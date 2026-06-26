#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test3() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    WORKFLOW_PATH=".github/workflows/train-pipeline.yml"

    response=$(curl -s -o /var/tmp/workflow_meta.json -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/contents/$WORKFLOW_PATH")

    if [ "$response" -ne 200 ]; then
        print_status "failed" "Workflow file not found at $WORKFLOW_PATH (HTTP $response)"
        return
    fi

    jq -r '.content' /var/tmp/workflow_meta.json \
        | tr -d '\n\r ' \
        | base64 -d > /var/tmp/workflow_decoded.yml 2>/dev/null

    if [ ! -s /var/tmp/workflow_decoded.yml ]; then
        print_status "failed" "Workflow file exists but could not be decoded"
        return
    fi

    print_status "success" "Workflow file found at $WORKFLOW_PATH"
}

Test3
