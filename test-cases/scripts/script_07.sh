#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test7() {

    if [ ! -f /var/tmp/workflow_decoded.yml ]; then
        print_status "failed" "Decoded workflow not available — skipping"
        return
    fi

    CONTENT=$(cat /var/tmp/workflow_decoded.yml)

    HAS_AWS_CREDS=false
    HAS_ECR_LOGIN=false
    HAS_SSH_ACTION=false

    # Check for AWS credentials action
    if echo "$CONTENT" | grep -q "aws-actions/configure-aws-credentials"; then
        HAS_AWS_CREDS=true
    fi

    # Check for ECR login action
    if echo "$CONTENT" | grep -q "aws-actions/amazon-ecr-login"; then
        HAS_ECR_LOGIN=true
    fi

    # Check for SSH deploy action
    if echo "$CONTENT" | grep -q "appleboy/ssh-action"; then
        HAS_SSH_ACTION=true
    fi

    if $HAS_AWS_CREDS && $HAS_ECR_LOGIN && $HAS_SSH_ACTION; then
        print_status "success" "AWS ECR login and SSH deploy actions configured correctly"
    else
        MISSING=""
        $HAS_AWS_CREDS || MISSING="$MISSING [aws-actions/configure-aws-credentials]"
        $HAS_ECR_LOGIN || MISSING="$MISSING [aws-actions/amazon-ecr-login]"
        $HAS_SSH_ACTION || MISSING="$MISSING [appleboy/ssh-action]"
        print_status "failed" "Missing actions:$MISSING"
    fi
}

Test7
