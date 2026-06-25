#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REGION="us-west-2"

Test1() {
    # Recover domain ID
    DOMAIN_ID=""
    if [ -f "/home/user/domain_id.txt" ]; then
        DOMAIN_ID=$(cat /home/user/domain_id.txt 2>/dev/null | tr -d '\n\r ')
    fi
    if [ -z "$DOMAIN_ID" ]; then
        DOMAIN_ID=$(grep -o 'd-[a-zA-Z0-9]*' /home/user/setup_log.txt 2>/dev/null | head -1 || echo "")
    fi

    if [ -z "$DOMAIN_ID" ]; then
        print_status "failed" "No domain ID found — run setup_studio.sh first"
        return
    fi

    # Save for later test scripts
    echo "$DOMAIN_ID" > /var/tmp/domain_id.txt

    # Check domain is InService
    DOMAIN_STATUS=$(aws sagemaker describe-domain \
        --domain-id "$DOMAIN_ID" \
        --region "$REGION" \
        --query 'Status' \
        --output text \
        --no-cli-pager 2>/dev/null || echo "NotFound")

    if [ "$DOMAIN_STATUS" != "InService" ]; then
        print_status "failed" "Studio domain status is '$DOMAIN_STATUS' (expected InService)"
        return
    fi

    # Check Canvas app was launched (describe-app with known parameters)
    CANVAS_STATUS=$(aws sagemaker describe-app \
        --domain-id "$DOMAIN_ID" \
        --user-profile-name "canvas-user" \
        --app-type Canvas \
        --app-name default \
        --region "$REGION" \
        --query 'Status' \
        --output text \
        --no-cli-pager 2>/dev/null || echo "NotFound")

    # Canvas app may be InService (running) or Deleted (was used then stopped)
    if [ "$CANVAS_STATUS" = "InService" ] || [ "$CANVAS_STATUS" = "Deleted" ]; then
        print_status "success" "Studio domain InService and Canvas app was launched ($DOMAIN_ID)"
    elif [ "$CANVAS_STATUS" = "NotFound" ]; then
        print_status "failed" "Studio domain is InService but Canvas was never opened — open Canvas in Studio first"
    else
        print_status "failed" "Studio domain is InService but Canvas app status is '$CANVAS_STATUS'"
    fi
}

Test1
