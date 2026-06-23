#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDENTIALS_FILE="/home/user/github_creds.json"
WORKFLOW_NAME="MLOps CI/CD Pipeline"

Test8() {

    ACCESS_TOKEN=$(jq -r '.access_token' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username' "$CREDENTIALS_FILE")
    REPO=$(jq -r '.repository_name' "$CREDENTIALS_FILE")

    curl -s \
      -H "Authorization: token $ACCESS_TOKEN" \
      "https://api.github.com/repos/$USERNAME/$REPO/actions/runs?per_page=20" \
      > /var/tmp/runs.json

    RUN_ID=$(jq -r ".workflow_runs[] | select(.name==\"$WORKFLOW_NAME\" and .conclusion==\"success\") | .id" /var/tmp/runs.json | head -n1)

    if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
        echo "$RUN_ID" > /var/tmp/run_id.txt
        print_status "success" "Successful workflow run found (Run ID: $RUN_ID)"
    else
        ANY_RUN=$(jq -r ".workflow_runs[] | select(.name==\"$WORKFLOW_NAME\") | .id" /var/tmp/runs.json | head -n1)
        if [ -n "$ANY_RUN" ] && [ "$ANY_RUN" != "null" ]; then
            CONCLUSION=$(jq -r ".workflow_runs[] | select(.name==\"$WORKFLOW_NAME\") | .conclusion" /var/tmp/runs.json | head -n1)
            print_status "failed" "Workflow run found but not successful (status: $CONCLUSION)"
        else
            print_status "failed" "No workflow run found for '$WORKFLOW_NAME'"
        fi
    fi
}

Test8
