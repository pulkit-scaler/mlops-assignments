#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

REG_FILE="/home/user/model-registry-lab/registration_details.json"

Test8() {
    if [ ! -f "$REG_FILE" ]; then
        print_status "failed" "registration_details.json not found at $REG_FILE"
        return
    fi

    if ! jq empty "$REG_FILE" 2>/dev/null; then
        print_status "failed" "registration_details.json is not valid JSON"
        return
    fi

    cp "$REG_FILE" /var/tmp/registration_details.json 2>/dev/null

    print_status "success" "registration_details.json exists and is valid JSON"
}

Test8
