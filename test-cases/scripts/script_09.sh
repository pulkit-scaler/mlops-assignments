#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

# Test 9: A successful workflow run exists
Test9() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    curl -s \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/actions/runs?per_page=20" \
        > /var/tmp/runs.json 2>/dev/null

    RUN_ID=$(jq -r '
        .workflow_runs[]
        | select(.name == "MLflow Training Pipeline" and .conclusion == "success")
        | .id
    ' /var/tmp/runs.json 2>/dev/null | head -n1)

    if [ -z "$RUN_ID" ]; then
        print_status "failed" "No successful 'MLflow Training Pipeline' run found — trigger the workflow and wait for it to pass"
        return
    fi

    echo "$RUN_ID" > /var/tmp/successful_run_id.txt
    print_status "success" "Successful 'MLflow Training Pipeline' run found (run_id=$RUN_ID)"
}

Test9
