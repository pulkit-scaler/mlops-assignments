#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test3() {
    if [ ! -f /var/tmp/feature_group.json ]; then
        print_status "failed" "Feature group info not found — script_02 may have failed"
        return
    fi

    STATUS=$(jq -r '.FeatureGroupStatus // empty' /var/tmp/feature_group.json)

    if [ "$STATUS" = "Created" ]; then
        print_status "success" "Feature group status is 'Created'"
    else
        print_status "failed" "Feature group status is '$STATUS' (expected 'Created')"
    fi
}

Test3
