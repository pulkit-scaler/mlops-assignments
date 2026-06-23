#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDENTIALS_FILE="/home/user/github_creds.json"

Test9() {

    if [ ! -f /var/tmp/run_id.txt ]; then
        print_status "failed" "No successful run ID available — skipping"
        return
    fi

    RUN_ID=$(cat /var/tmp/run_id.txt)
    ACCESS_TOKEN=$(jq -r '.access_token' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username' "$CREDENTIALS_FILE")
    REPO=$(jq -r '.repository_name' "$CREDENTIALS_FILE")

    curl -s \
      -H "Authorization: token $ACCESS_TOKEN" \
      "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID/jobs" \
      > /var/tmp/jobs.json

    JOB_COUNT=$(jq '.jobs | length' /var/tmp/jobs.json)
    SUCCESS_COUNT=$(jq '[.jobs[] | select(.conclusion=="success")] | length' /var/tmp/jobs.json)

    if [ "$JOB_COUNT" -ge 3 ] && [ "$SUCCESS_COUNT" -ge 3 ]; then
        HAS_BUILD=$(jq '[.jobs[] | select(.name=="build" and .conclusion=="success")] | length' /var/tmp/jobs.json)
        HAS_PUSH=$(jq '[.jobs[] | select(.name=="push" and .conclusion=="success")] | length' /var/tmp/jobs.json)
        HAS_DEPLOY=$(jq '[.jobs[] | select(.name=="deploy" and .conclusion=="success")] | length' /var/tmp/jobs.json)

        if [ "$HAS_BUILD" -ge 1 ] && [ "$HAS_PUSH" -ge 1 ] && [ "$HAS_DEPLOY" -ge 1 ]; then
            print_status "success" "All 3 jobs (build, push, deploy) completed successfully"
        else
            MISSING=""
            [ "$HAS_BUILD" -lt 1 ] && MISSING="$MISSING build"
            [ "$HAS_PUSH" -lt 1 ] && MISSING="$MISSING push"
            [ "$HAS_DEPLOY" -lt 1 ] && MISSING="$MISSING deploy"
            print_status "failed" "Missing successful jobs:$MISSING"
        fi
    else
        print_status "failed" "Expected 3+ successful jobs, found $SUCCESS_COUNT of $JOB_COUNT"
    fi
}

Test9
