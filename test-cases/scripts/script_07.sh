#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"

# Test 7: train.py contains all required MLflow calls
Test7() {
    ACCESS_TOKEN=$(cat /var/tmp/gh_token.txt 2>/dev/null || echo "")
    USERNAME=$(cat /var/tmp/gh_username.txt 2>/dev/null || echo "")
    REPO=$(cat /var/tmp/gh_repo.txt 2>/dev/null || echo "")

    if [ -z "$ACCESS_TOKEN" ] || [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
        print_status "failed" "Repository info not found — did Test 2 pass?"
        return
    fi

    response=$(curl -s -o /var/tmp/train_meta.json -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO/contents/train.py")

    if [ "$response" -ne 200 ]; then
        print_status "failed" "train.py not found in repository root (HTTP $response)"
        return
    fi

    jq -r '.content' /var/tmp/train_meta.json \
        | tr -d '\n\r ' \
        | base64 -d > /var/tmp/train_decoded.py 2>/dev/null

    if [ ! -s /var/tmp/train_decoded.py ]; then
        print_status "failed" "train.py could not be decoded"
        return
    fi

    ERRORS=""

    grep -q "mlflow.set_tracking_uri" /var/tmp/train_decoded.py || \
        ERRORS="$ERRORS | missing mlflow.set_tracking_uri()"

    grep -q "mlflow.set_experiment" /var/tmp/train_decoded.py || \
        ERRORS="$ERRORS | missing mlflow.set_experiment()"

    grep -q "mlflow.start_run" /var/tmp/train_decoded.py || \
        ERRORS="$ERRORS | missing mlflow.start_run()"

    grep -qE "mlflow\.log_param(s)?\(" /var/tmp/train_decoded.py || \
        ERRORS="$ERRORS | missing mlflow.log_param/log_params()"

    grep -qE "mlflow\.log_metric(s)?\(" /var/tmp/train_decoded.py || \
        ERRORS="$ERRORS | missing mlflow.log_metric/log_metrics()"

    grep -q "mlflow.sklearn.log_model" /var/tmp/train_decoded.py || \
        ERRORS="$ERRORS | missing mlflow.sklearn.log_model()"

    if [ -n "$ERRORS" ]; then
        print_status "failed" "train.py is missing required MLflow calls:$ERRORS"
        return
    fi

    print_status "success" "train.py contains all required MLflow tracking calls"
}

Test7
