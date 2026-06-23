#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test4() {

    if [ ! -f /var/tmp/workflow.json ]; then
        print_status "failed" "Workflow file not retrieved — skipping"
        return
    fi

    CONTENT=$(jq -r '.content' /var/tmp/workflow.json | tr -d '\n\r ' | base64 -d 2>/dev/null)

    if [ -z "$CONTENT" ]; then
        print_status "failed" "Could not decode workflow content"
        return
    fi

    echo "$CONTENT" > /var/tmp/workflow_decoded.yml

    HAS_NAME=false
    HAS_PUSH_MAIN=false
    HAS_DISPATCH=false

    if echo "$CONTENT" | grep -qi "MLOps CI/CD Pipeline"; then
        HAS_NAME=true
    fi

    if echo "$CONTENT" | grep -q "push" && echo "$CONTENT" | grep -q "main"; then
        HAS_PUSH_MAIN=true
    fi

    if echo "$CONTENT" | grep -q "workflow_dispatch"; then
        HAS_DISPATCH=true
    fi

    if $HAS_NAME && $HAS_PUSH_MAIN && $HAS_DISPATCH; then
        print_status "success" "Workflow name and triggers configured correctly"
    else
        MISSING=""
        $HAS_NAME || MISSING="$MISSING name='MLOps CI/CD Pipeline'"
        $HAS_PUSH_MAIN || MISSING="$MISSING push-to-main"
        $HAS_DISPATCH || MISSING="$MISSING workflow_dispatch"
        print_status "failed" "Missing:$MISSING"
    fi
}

Test4
