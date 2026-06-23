#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test5() {

    if [ ! -f /var/tmp/workflow_decoded.yml ]; then
        print_status "failed" "Decoded workflow not available — skipping"
        return
    fi

    CONTENT=$(cat /var/tmp/workflow_decoded.yml)

    HAS_API_IMAGE=false
    HAS_DASHBOARD_IMAGE=false
    HAS_IMAGE_TAG=false

    if echo "$CONTENT" | grep -q "API_IMAGE_NAME" && echo "$CONTENT" | grep -q "mlops-api"; then
        HAS_API_IMAGE=true
    fi

    if echo "$CONTENT" | grep -q "DASHBOARD_IMAGE_NAME" && echo "$CONTENT" | grep -q "mlops-dashboard"; then
        HAS_DASHBOARD_IMAGE=true
    fi

    if echo "$CONTENT" | grep -q "IMAGE_TAG" && echo "$CONTENT" | grep -q "github.sha"; then
        HAS_IMAGE_TAG=true
    fi

    if $HAS_API_IMAGE && $HAS_DASHBOARD_IMAGE && $HAS_IMAGE_TAG; then
        print_status "success" "Workflow environment variables configured correctly"
    else
        MISSING=""
        $HAS_API_IMAGE || MISSING="$MISSING API_IMAGE_NAME"
        $HAS_DASHBOARD_IMAGE || MISSING="$MISSING DASHBOARD_IMAGE_NAME"
        $HAS_IMAGE_TAG || MISSING="$MISSING IMAGE_TAG"
        print_status "failed" "Missing or misconfigured env vars:$MISSING"
    fi
}

Test5
