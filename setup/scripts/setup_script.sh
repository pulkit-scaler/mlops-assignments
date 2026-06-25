#!/bin/bash

set -euo pipefail
REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BASE_DIR="/home/user/feature-store-lab"
FEATURE_GROUP_NAME="iris-features"
S3_BUCKET="feature-store-lab-${ACCOUNT_ID}"
ROLE_NAME="SageMakerFeatureStoreRole"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo "================================================"
echo "Feature Store Lab - Setup"
echo "================================================"
echo "Region: ${REGION} | Account: ${ACCOUNT_ID}"
echo ""

# ==========================================
# 1. Create S3 bucket for Feature Store offline store
# ==========================================
echo "[1/6] Installing Python..."

apt-get update -y -qq
apt-get install -y -qq python3 python3-pip
echo "  Python ready: $(python3 --version)"

# ==========================================
# 2. Create S3 bucket for Feature Store offline store
# ==========================================
echo "[2/6] Creating S3 bucket..."

aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || true

echo "  Bucket ready: $S3_BUCKET"

# ==========================================
# 2. Create SageMaker execution role for offline store
# ==========================================
echo "[3/6] Creating SageMaker execution role..."

TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"sagemaker.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --no-cli-pager 2>/dev/null || true

INLINE_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:PutObject","s3:GetObject","s3:DeleteObject","s3:ListBucket","s3:GetBucketAcl","s3:GetBucketLocation"],"Resource":["arn:aws:s3:::'${S3_BUCKET}'","arn:aws:s3:::'${S3_BUCKET}'/*"]}]}'

aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "FeatureStoreS3Access" \
    --policy-document "$INLINE_POLICY" \
    --no-cli-pager 2>/dev/null || true

echo "  Role ready: $ROLE_ARN"

# ==========================================
# 3. Save AWS Credentials
# ==========================================
echo "[4/6] Saving AWS credentials..."

if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    CRED_KEY="$AWS_ACCESS_KEY_ID"
    CRED_SECRET="$AWS_SECRET_ACCESS_KEY"
else
    CRED_KEY=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
    CRED_SECRET=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
fi

if [ -z "$CRED_KEY" ] || [ -z "$CRED_SECRET" ]; then
    echo "  ERROR: Could not extract AWS credentials"
    exit 1
fi

cat > /home/user/aws_iam_creds.json <<CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}"
}
CREDS
chmod 600 /home/user/aws_iam_creds.json
echo "  Credentials saved"

# ==========================================
# 4. Create Project Files
# ==========================================
echo "[5/6] Creating project files..."

mkdir -p "${BASE_DIR}"

cat > "${BASE_DIR}/sample_data.json" <<'DATAEOF'
[
  {"record_id": "1",  "sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "2",  "sepal_length": 4.9, "sepal_width": 3.0, "petal_length": 1.4, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "3",  "sepal_length": 4.7, "sepal_width": 3.2, "petal_length": 1.3, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "4",  "sepal_length": 4.6, "sepal_width": 3.1, "petal_length": 1.5, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "5",  "sepal_length": 5.0, "sepal_width": 3.6, "petal_length": 1.4, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "6",  "sepal_length": 7.0, "sepal_width": 3.2, "petal_length": 4.7, "petal_width": 1.4, "species": "versicolor", "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "7",  "sepal_length": 6.4, "sepal_width": 3.2, "petal_length": 4.5, "petal_width": 1.5, "species": "versicolor", "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "8",  "sepal_length": 6.9, "sepal_width": 3.1, "petal_length": 4.9, "petal_width": 1.5, "species": "versicolor", "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "9",  "sepal_length": 5.5, "sepal_width": 2.3, "petal_length": 4.0, "petal_width": 1.3, "species": "versicolor", "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "10", "sepal_length": 6.5, "sepal_width": 2.8, "petal_length": 4.6, "petal_width": 1.5, "species": "versicolor", "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "11", "sepal_length": 6.3, "sepal_width": 3.3, "petal_length": 6.0, "petal_width": 2.5, "species": "virginica",  "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "12", "sepal_length": 5.8, "sepal_width": 2.7, "petal_length": 5.1, "petal_width": 1.9, "species": "virginica",  "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "13", "sepal_length": 7.1, "sepal_width": 3.0, "petal_length": 5.9, "petal_width": 2.1, "species": "virginica",  "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "14", "sepal_length": 6.3, "sepal_width": 2.9, "petal_length": 5.6, "petal_width": 1.8, "species": "virginica",  "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "15", "sepal_length": 6.5, "sepal_width": 3.0, "petal_length": 5.8, "petal_width": 2.2, "species": "virginica",  "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "16", "sepal_length": 5.4, "sepal_width": 3.9, "petal_length": 1.7, "petal_width": 0.4, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "17", "sepal_length": 4.6, "sepal_width": 3.4, "petal_length": 1.4, "petal_width": 0.3, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "18", "sepal_length": 5.0, "sepal_width": 3.4, "petal_length": 1.5, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "19", "sepal_length": 4.4, "sepal_width": 2.9, "petal_length": 1.4, "petal_width": 0.2, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"},
  {"record_id": "20", "sepal_length": 4.9, "sepal_width": 3.1, "petal_length": 1.5, "petal_width": 0.1, "species": "setosa",     "event_time": "2024-01-01T00:00:00Z"}
]
DATAEOF

cat > "${BASE_DIR}/requirements.txt" <<'REQEOF'
boto3>=1.28.0
REQEOF

cat > "${BASE_DIR}/README.md" <<READMEEOF
# Iris Feature Store Lab

## Files
- sample_data.json       - 20 Iris records to ingest
- requirements.txt       - Python dependencies
- ingest_features.py     - [You write this]
- retrieved_records.json - [Auto-created by your script]

## Feature Group Config
Name: ${FEATURE_GROUP_NAME}
Record identifier: record_id
Event time: event_time
Offline store: s3://${S3_BUCKET}/feature-store/
Role ARN: ${ROLE_ARN}
READMEEOF

# ==========================================
# 5. Save environment info
# ==========================================
echo "[6/6] Saving environment info..."

cat > /home/user/lab_env.txt <<ENVEOF
REGION=${REGION}
ACCOUNT_ID=${ACCOUNT_ID}
S3_BUCKET=${S3_BUCKET}
FEATURE_GROUP_NAME=${FEATURE_GROUP_NAME}
ROLE_ARN=${ROLE_ARN}
PROJECT_DIR=${BASE_DIR}
ENVEOF

chown -R user:user "${BASE_DIR}" 2>/dev/null || true
chown user:user /home/user/lab_env.txt /home/user/aws_iam_creds.json 2>/dev/null || true

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo "  S3 bucket:     ${S3_BUCKET}"
echo "  IAM role:      ${ROLE_ARN}"
echo "  AWS creds:     /home/user/aws_iam_creds.json"
echo "  Project files: ${BASE_DIR}"
echo "  Env info:      /home/user/lab_env.txt"
echo "================================================"
