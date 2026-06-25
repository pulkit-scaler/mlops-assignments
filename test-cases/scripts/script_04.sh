#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test4() {
    if [ ! -f /var/tmp/feature_group.json ]; then
        print_status "failed" "Feature group info not found — script_02 may have failed"
        return
    fi

    ONLINE_ENABLED=$(jq -r '.OnlineStoreConfig.EnableOnlineStore // "false"' /var/tmp/feature_group.json)

    if [ "$ONLINE_ENABLED" = "true" ]; then
        print_status "success" "Online store is enabled"
    else
        print_status "failed" "Online store is not enabled — recreate the feature group with EnableOnlineStore: true"
    fi
}

Test4
