#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

CREDENTIALS_FILE="/home/user/github_creds.json"

Test2() {
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        print_status "failed" "Missing github_creds.json"
        return
    fi

    ACCESS_TOKEN=$(jq -r '.access_token // empty' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username // empty' "$CREDENTIALS_FILE")
    REPO=$(jq -r '.repository_name // empty' "$CREDENTIALS_FILE")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "github_creds.json is missing access_token, username, or repository_name"
        return
    fi

    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO")

    if [ "$response" -ne 200 ]; then
        print_status "failed" "Repository $USERNAME/$REPO not found (HTTP $response)"
        return
    fi

    echo "$USERNAME"    > /var/tmp/gh_username.txt
    echo "$REPO"        > /var/tmp/gh_repo.txt
    echo "$ACCESS_TOKEN" > /var/tmp/gh_token.txt

    print_status "success" "Repository $USERNAME/$REPO exists and is accessible"
}

Test2
