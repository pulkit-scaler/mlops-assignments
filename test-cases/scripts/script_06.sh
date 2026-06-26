#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

# Test 6: wine.csv.dvc pointer file exists in repo AND data is in S3
Test6() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    EXPECTED_BUCKET=$(grep S3_BUCKET /home/user/lab_env.txt 2>/dev/null | cut -d= -f2)
    REGION=$(grep "^REGION=" /home/user/lab_env.txt 2>/dev/null | cut -d= -f2)

    # Check that data/wine.csv.dvc pointer exists in the repo
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/contents/data/wine.csv.dvc")

    if [ "$response" -ne 200 ]; then
        print_status "failed" "data/wine.csv.dvc not found in repo — did you run dvc add data/wine.csv and commit?"
        return
    fi

    # Check that DVC cache files actually exist in S3
    FILES=$(aws s3 ls "s3://${EXPECTED_BUCKET}/" \
        --recursive --region "${REGION}" --no-cli-pager 2>/dev/null | wc -l | tr -d ' ')

    if [ "${FILES:-0}" -lt 1 ]; then
        print_status "failed" "No files found in s3://${EXPECTED_BUCKET} — did you run dvc push?"
        return
    fi

    print_status "success" "wine.csv.dvc committed to repo and data pushed to S3"
}

Test6
