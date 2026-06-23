#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

WORKFLOW_PATH=".github/workflows/deploy-pipeline.yml"
CREDENTIALS_FILE="/home/user/github_creds.json"

Test3() {

    ACCESS_TOKEN=$(jq -r '.access_token' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username' "$CREDENTIALS_FILE")
    REPO=$(jq -r '.repository_name' "$CREDENTIALS_FILE")

    response=$(curl -s -o /var/tmp/workflow.json -w "%{http_code}" \
      -H "Authorization: token $ACCESS_TOKEN" \
      https://api.github.com/repos/$USERNAME/$REPO/contents/$WORKFLOW_PATH)

    if [ "$response" -eq 200 ]; then
        print_status "success" "Workflow file deploy-pipeline.yml exists at correct path"
    else
        print_status "failed" "Workflow file not found at .github/workflows/deploy-pipeline.yml"
    fi
}

Test3
