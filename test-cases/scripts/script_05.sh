#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

Test5() {
    if [ ! -f /var/tmp/feature_group.json ]; then
        print_status "failed" "Feature group info not found — script_02 may have failed"
        return
    fi

    REC_ID=$(jq -r '.RecordIdentifierFeatureName // empty' /var/tmp/feature_group.json)
    EVT_TIME=$(jq -r '.EventTimeFeatureName // empty' /var/tmp/feature_group.json)

    if [ "$REC_ID" = "record_id" ] && [ "$EVT_TIME" = "event_time" ]; then
        print_status "success" "Record identifier is 'record_id' and event time is 'event_time'"
    elif [ "$REC_ID" != "record_id" ]; then
        print_status "failed" "Record identifier is '$REC_ID' (expected 'record_id')"
    else
        print_status "failed" "Event time feature is '$EVT_TIME' (expected 'event_time')"
    fi
}

Test5
