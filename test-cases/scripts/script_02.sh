#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDENTIALS_FILE="/home/user/github_creds.json"

Test2() {

    ACCESS_TOKEN=$(jq -r '.access_token' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username' "$CREDENTIALS_FILE")
    REPO=$(jq -r '.repository_name' "$CREDENTIALS_FILE")

    response=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: token $ACCESS_TOKEN" \
      https://api.github.com/repos/$USERNAME/$REPO)

    if [ "$response" -eq 200 ]; then
        print_status "success" "Repository $USERNAME/$REPO exists"
    else
        print_status "failed" "Repository $USERNAME/$REPO not found (HTTP $response)"
    fi
}

Test2
