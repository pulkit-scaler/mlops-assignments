#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

SCRIPT_PATH="/home/user/feature-store-lab/ingest_features.py"

Test8() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_status "failed" "ingest_features.py not found — cannot inspect content"
        return
    fi

    HAS_BOTO3=$(grep -c "import boto3" "$SCRIPT_PATH" || echo "0")
    HAS_CLIENT=$(grep -c "sagemaker-featurestore-runtime" "$SCRIPT_PATH" || echo "0")
    HAS_PUT=$(grep -c "put_record" "$SCRIPT_PATH" || echo "0")
    HAS_GET=$(grep -c "get_record" "$SCRIPT_PATH" || echo "0")

    if [ "$HAS_BOTO3" -gt "0" ] && [ "$HAS_CLIENT" -gt "0" ] && [ "$HAS_PUT" -gt "0" ] && [ "$HAS_GET" -gt "0" ]; then
        print_status "success" "Script uses boto3 sagemaker-featurestore-runtime client with put_record and get_record"
    elif [ "$HAS_BOTO3" -eq "0" ]; then
        print_status "failed" "Script does not import boto3"
    elif [ "$HAS_CLIENT" -eq "0" ]; then
        print_status "failed" "Script does not use the sagemaker-featurestore-runtime client"
    elif [ "$HAS_PUT" -eq "0" ]; then
        print_status "failed" "Script does not call put_record — ingestion logic missing"
    else
        print_status "failed" "Script does not call get_record — retrieval logic missing"
    fi
}

Test8
