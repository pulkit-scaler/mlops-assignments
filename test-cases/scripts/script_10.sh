#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

# Test 10: Both train and report jobs completed successfully + artifact exists
Test10() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")
    RUN_ID=$(cat /var/tmp/successful_run_id.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    if [ -z "$RUN_ID" ]; then
        print_status "failed" "No successful run ID found — did Test 9 pass?"
        return
    fi

    curl -s \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID/jobs" \
        > /var/tmp/jobs.json 2>/dev/null

    TRAIN_SUCCESS=$(jq '[.jobs[] | select(.name == "train" and .conclusion == "success")] | length' \
        /var/tmp/jobs.json 2>/dev/null)

    REPORT_SUCCESS=$(jq '[.jobs[] | select(.name == "report" and .conclusion == "success")] | length' \
        /var/tmp/jobs.json 2>/dev/null)

    if [ "${TRAIN_SUCCESS:-0}" -lt 1 ]; then
        print_status "failed" "Job 'train' did not complete successfully"
        return
    fi

    if [ "${REPORT_SUCCESS:-0}" -lt 1 ]; then
        print_status "failed" "Job 'report' did not complete successfully"
        return
    fi

    # Verify the workflow actually produced the mlruns artifact
    curl -s \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID/artifacts" \
        > /var/tmp/artifacts.json 2>/dev/null

    HAS_ARTIFACT=$(jq '[.artifacts[] | select(.name == "mlruns-artifact")] | length' \
        /var/tmp/artifacts.json 2>/dev/null)

    if [ "${HAS_ARTIFACT:-0}" -lt 1 ]; then
        print_status "failed" "Both jobs passed but 'mlruns-artifact' was not produced — workflow must run real experiments"
        return
    fi

    print_status "success" "Both jobs (train and report) completed successfully with mlruns artifact"
}

Test10
