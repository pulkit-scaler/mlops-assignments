#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

# Test 8: query_runs.py contains MlflowClient usage
Test8() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    response=$(curl -s -o /var/tmp/query_meta.json -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/contents/query_runs.py")

    if [ "$response" -ne 200 ]; then
        print_status "failed" "query_runs.py not found in repository root (HTTP $response)"
        return
    fi

    jq -r '.content' /var/tmp/query_meta.json \
        | tr -d '\n\r ' \
        | base64 -d > /var/tmp/query_decoded.py 2>/dev/null

    if [ ! -s /var/tmp/query_decoded.py ]; then
        print_status "failed" "query_runs.py could not be decoded"
        return
    fi

    ERRORS=""

    grep -q "MlflowClient" /var/tmp/query_decoded.py || \
        ERRORS="$ERRORS | missing MlflowClient"

    grep -q "get_experiment_by_name" /var/tmp/query_decoded.py || \
        ERRORS="$ERRORS | missing get_experiment_by_name()"

    grep -q "search_runs" /var/tmp/query_decoded.py || \
        ERRORS="$ERRORS | missing search_runs()"

    if [ -n "$ERRORS" ]; then
        print_status "failed" "query_runs.py is missing required MlflowClient usage:$ERRORS"
        return
    fi

    print_status "success" "query_runs.py contains MlflowClient, get_experiment_by_name, and search_runs"
}

Test8
