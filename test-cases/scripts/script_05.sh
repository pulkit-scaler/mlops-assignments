#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

# Test 5: DVC is initialised and remote points to the correct S3 bucket
Test5() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    # Read the expected bucket name from lab_env.txt
    EXPECTED_BUCKET=$(grep S3_BUCKET /home/user/lab_env.txt 2>/dev/null | cut -d= -f2)
    if [ -z "$EXPECTED_BUCKET" ]; then
        print_status "failed" "S3_BUCKET not found in /home/user/lab_env.txt"
        return
    fi

    # Fetch .dvc/config from the repo
    response=$(curl -s -o /var/tmp/dvc_config_meta.json -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/contents/.dvc/config")

    if [ "$response" -ne 200 ]; then
        print_status "failed" ".dvc/config not found in repo — did you run dvc init and dvc remote add?"
        return
    fi

    jq -r '.content' /var/tmp/dvc_config_meta.json \
        | tr -d '\n\r ' \
        | base64 -d > /var/tmp/dvc_config.txt 2>/dev/null

    if ! grep -q "s3://${EXPECTED_BUCKET}" /var/tmp/dvc_config.txt; then
        print_status "failed" "DVC remote URL does not point to the expected bucket s3://${EXPECTED_BUCKET}"
        return
    fi

    print_status "success" "DVC remote correctly configured pointing to s3://${EXPECTED_BUCKET}"
}

Test5
