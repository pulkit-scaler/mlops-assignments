#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test6() {

    if [ ! -f /var/tmp/workflow_decoded.yml ]; then
        print_status "failed" "Decoded workflow not available — skipping"
        return
    fi

    CONTENT=$(cat /var/tmp/workflow_decoded.yml)

    HAS_BUILD=false
    HAS_PUSH=false
    HAS_DEPLOY=false

    if echo "$CONTENT" | grep -qE "^\s+build:"; then
        HAS_BUILD=true
    fi

    if echo "$CONTENT" | grep -qE "^\s+push:"; then
        HAS_PUSH=true
    fi

    if echo "$CONTENT" | grep -qE "^\s+deploy:"; then
        HAS_DEPLOY=true
    fi

    # Check dependency chain: push needs build, deploy needs push
    PUSH_NEEDS_BUILD=false
    DEPLOY_NEEDS_PUSH=false

    if echo "$CONTENT" | grep -A5 "push:" | grep -q "needs:.*build"; then
        PUSH_NEEDS_BUILD=true
    fi

    if echo "$CONTENT" | grep -A5 "deploy:" | grep -q "needs:.*push"; then
        DEPLOY_NEEDS_PUSH=true
    fi

    if $HAS_BUILD && $HAS_PUSH && $HAS_DEPLOY && $PUSH_NEEDS_BUILD && $DEPLOY_NEEDS_PUSH; then
        print_status "success" "All 3 jobs with correct dependency chain: build → push → deploy"
    else
        MISSING=""
        $HAS_BUILD || MISSING="$MISSING [job:build]"
        $HAS_PUSH || MISSING="$MISSING [job:push]"
        $HAS_DEPLOY || MISSING="$MISSING [job:deploy]"
        $PUSH_NEEDS_BUILD || MISSING="$MISSING [push needs build]"
        $DEPLOY_NEEDS_PUSH || MISSING="$MISSING [deploy needs push]"
        print_status "failed" "Missing:$MISSING"
    fi
}

Test6
