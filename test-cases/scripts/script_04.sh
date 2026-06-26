#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test4() {
    WORKFLOW_FILE="/var/tmp/workflow_decoded.yml"

    if [ ! -s "$WORKFLOW_FILE" ]; then
        print_status "failed" "Workflow file not decoded — did Test 3 pass?"
        return
    fi

    if ! grep -q "name:.*MLflow Training Pipeline" "$WORKFLOW_FILE"; then
        print_status "failed" "Workflow name must be exactly 'MLflow Training Pipeline'"
        return
    fi

    if ! grep -q "push:" "$WORKFLOW_FILE"; then
        print_status "failed" "Workflow must trigger on push — missing push trigger"
        return
    fi

    if ! grep -q "workflow_dispatch" "$WORKFLOW_FILE"; then
        print_status "failed" "Workflow must trigger on workflow_dispatch — missing dispatch trigger"
        return
    fi

    print_status "success" "Workflow name and triggers are correct"
}

Test4
