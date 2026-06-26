#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDENTIALS_FILE="/home/user/github_creds.json"

Test1() {
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        print_status "failed" "Missing /home/user/github_creds.json"
        return
    fi

    ACCESS_TOKEN=$(jq -r '.access_token // empty' "$CREDENTIALS_FILE")
    if [ -z "$ACCESS_TOKEN" ]; then
        print_status "failed" "access_token missing in github_creds.json"
        return
    fi

    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        https://api.github.com/user)

    if [ "$response" -eq 200 ]; then
        print_status "success" "GitHub authentication successful"
    else
        print_status "failed" "GitHub authentication failed (HTTP $response)"
    fi
}

Test1
