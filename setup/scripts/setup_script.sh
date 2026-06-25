#!/bin/bash

set -euo pipefail
BASE_DIR="/home/user/model-registry-lab"
REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "================================================"
echo "SageMaker Model Registry + Canvas Lab - Setup"
echo "================================================"
echo "Region: ${REGION} | Account: ${ACCOUNT_ID}"
echo ""

# ==========================================
# 1. Install Python3 + pip + boto3 + scikit-learn
# ==========================================
echo "[1/6] Installing Python and dependencies..."

apt-get update -y -qq
apt-get install -y -qq python3 python3-pip > /dev/null 2>&1
python3 -m pip install boto3 scikit-learn --quiet --break-system-packages 2>/dev/null \
    || python3 -m pip install boto3 scikit-learn --quiet

echo "  ✓ Python ready: $(python3 --version)"

# ==========================================
# 2. Save AWS Credentials (reuse container's own creds)
# ==========================================
echo "[2/6] Saving AWS credentials..."

if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    CRED_KEY="$AWS_ACCESS_KEY_ID"
    CRED_SECRET="$AWS_SECRET_ACCESS_KEY"
    CRED_TOKEN="${AWS_SESSION_TOKEN:-}"
else
    CRED_KEY=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
    CRED_SECRET=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
    CRED_TOKEN=$(aws configure get aws_session_token 2>/dev/null || echo "")
fi

if [ -z "$CRED_KEY" ] || [ -z "$CRED_SECRET" ]; then
    echo "  ERROR: Could not extract AWS credentials"
    exit 1
fi

if [ -n "$CRED_TOKEN" ]; then
    cat > /home/user/aws_iam_creds.json <<CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}",
  "SessionToken": "${CRED_TOKEN}"
}
CREDS
    echo "  ✓ Credentials saved (includes session token)"
else
    cat > /home/user/aws_iam_creds.json <<CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}"
}
CREDS
    echo "  ✓ Credentials saved"
fi
chmod 600 /home/user/aws_iam_creds.json

# ==========================================
# 3. Create S3 Bucket + Upload Model Artifact
# ==========================================
echo "[3/6] Creating S3 bucket and model artifact..."

S3_BUCKET="sagemaker-registry-lab-${ACCOUNT_ID}"

aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || true
echo "  Bucket ready: $S3_BUCKET"

# Train a real sklearn model, tar.gz it, upload to S3
python3 -c "
import pickle, tarfile, os, json, csv
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score

iris = load_iris()
X_train, X_test, y_train, y_test = train_test_split(
    iris.data, iris.target, test_size=0.2, random_state=42)
model = RandomForestClassifier(n_estimators=100, max_depth=5, random_state=42)
model.fit(X_train, y_train)
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
f1 = f1_score(y_test, y_pred, average='weighted')

os.makedirs('/tmp/model-artifact', exist_ok=True)
with open('/tmp/model-artifact/model.pkl', 'wb') as f:
    pickle.dump(model, f)
metadata = {
    'algorithm': 'RandomForestClassifier', 'n_estimators': 100, 'max_depth': 5,
    'accuracy': round(accuracy, 4), 'f1_score': round(f1, 4),
    'n_features': 4, 'n_classes': 3,
    'feature_names': list(iris.feature_names),
    'target_names': list(iris.target_names)
}
with open('/tmp/model-artifact/metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

with tarfile.open('/tmp/iris-model.tar.gz', 'w:gz') as tar:
    tar.add('/tmp/model-artifact/model.pkl', arcname='model.pkl')
    tar.add('/tmp/model-artifact/metadata.json', arcname='metadata.json')

# Also create Iris CSV for Canvas
with open('/tmp/iris.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['sepal_length', 'sepal_width', 'petal_length', 'petal_width', 'species'])
    for features, target in zip(iris.data, iris.target):
        writer.writerow(list(features) + [iris.target_names[target]])

print(f'Model trained — accuracy: {accuracy:.4f}, f1: {f1:.4f}')
"

aws s3 cp /tmp/iris-model.tar.gz "s3://${S3_BUCKET}/models/iris-model.tar.gz" --region "$REGION" --quiet
aws s3 cp /tmp/iris.csv "s3://${S3_BUCKET}/datasets/iris.csv" --region "$REGION" --quiet
echo "  ✓ Model artifact + Iris CSV uploaded to S3"

# ==========================================
# 4. Create IAM Execution Role for SageMaker
# ==========================================
echo "[4/6] Creating SageMaker execution role..."

ROLE_NAME="SageMakerLabExecutionRole"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"sagemaker.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --no-cli-pager 2>/dev/null || true

ROLE_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket","s3:GetBucketAcl","s3:GetBucketLocation","s3:AbortMultipartUpload","s3:GetBucketCors","s3:PutBucketCors"],"Resource":["arn:aws:s3:::'"$S3_BUCKET"'","arn:aws:s3:::'"$S3_BUCKET"'/*","arn:aws:s3:::sagemaker-'"$REGION"'-'"$ACCOUNT_ID"'","arn:aws:s3:::sagemaker-'"$REGION"'-'"$ACCOUNT_ID"'/*"]},{"Effect":"Allow","Action":["s3:CreateBucket","s3:GetBucketLocation","s3:ListBucket"],"Resource":"arn:aws:s3:::sagemaker-*"},{"Effect":"Allow","Action":["sagemaker:*"],"Resource":"*"},{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"*"},{"Effect":"Allow","Action":["ecr:GetAuthorizationToken","ecr:BatchGetImage","ecr:GetDownloadUrlForLayer","ecr:BatchCheckLayerAvailability"],"Resource":"*"},{"Effect":"Allow","Action":["iam:GetRole","iam:PassRole"],"Resource":"*"}]}'

aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "SageMakerLabPolicy" \
    --policy-document "$ROLE_POLICY" \
    --no-cli-pager 2>/dev/null || true

echo "  ✓ IAM role: $ROLE_NAME"

# ==========================================
# 5. Create Project Directory + Helper Scripts
# ==========================================
echo "[5/6] Creating project files..."

mkdir -p ${BASE_DIR}

# --- Studio Domain Provisioning Helper ---
cat > ${BASE_DIR}/setup_studio.sh <<'HELPEREOF'
#!/bin/bash
set -euo pipefail

source /home/user/lab_env.txt
REGION="${REGION:-us-west-2}"
DOMAIN_NAME="canvas-lab-domain"
USER_PROFILE_NAME="canvas-user"
DOMAIN_FILE="/home/user/domain_id.txt"
LOG_FILE="/home/user/setup_log.txt"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Check if domain was already provisioned
if [ -f "$DOMAIN_FILE" ]; then
    EXISTING_ID=$(cat "$DOMAIN_FILE")
    STATUS=$(aws sagemaker describe-domain --domain-id "$EXISTING_ID" \
        --region "$REGION" --query 'Status' --output text --no-cli-pager 2>/dev/null || echo "NotFound")
    if [ "$STATUS" = "InService" ]; then
        log "Domain already provisioned and InService: $EXISTING_ID"
        exit 0
    elif [ "$STATUS" = "Pending" ]; then
        log "Domain is still provisioning: $EXISTING_ID — waiting..."
        DOMAIN_ID="$EXISTING_ID"
    else
        log "Previous domain not usable (status: $STATUS) — creating new one"
        rm -f "$DOMAIN_FILE"
    fi
fi

if [ -z "${DOMAIN_ID:-}" ]; then
    log "Looking up VPC and subnet..."
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" \
        --region "$REGION" --query 'Vpcs[0].VpcId' --output text --no-cli-pager)
    SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" --query 'Subnets[0].SubnetId' --output text --no-cli-pager)
    log "VPC: $VPC_ID | Subnet: $SUBNET_ID"

    log "Creating SageMaker Studio domain (this takes 5-8 minutes)..."
    DOMAIN_ARN=$(aws sagemaker create-domain \
        --domain-name "$DOMAIN_NAME" \
        --auth-mode IAM \
        --default-user-settings "{\"ExecutionRole\":\"${SAGEMAKER_ROLE_ARN}\"}" \
        --subnet-ids "$SUBNET_ID" \
        --vpc-id "$VPC_ID" \
        --region "$REGION" \
        --query 'DomainArn' --output text --no-cli-pager 2>/dev/null) || true

    if [ -z "$DOMAIN_ARN" ]; then
        log "ERROR: create-domain failed. Domain may already exist or permissions insufficient."
        exit 1
    fi

    DOMAIN_ID=$(echo "$DOMAIN_ARN" | grep -o 'd-[a-zA-Z0-9]*')
    echo "$DOMAIN_ID" > "$DOMAIN_FILE"
    log "Domain ID: $DOMAIN_ID"
fi

# Poll until InService
POLL_COUNT=0
MAX_POLLS=40
while [ $POLL_COUNT -lt $MAX_POLLS ]; do
    STATUS=$(aws sagemaker describe-domain --domain-id "$DOMAIN_ID" \
        --region "$REGION" --query 'Status' --output text --no-cli-pager 2>/dev/null || echo "Unknown")
    log "Domain status: $STATUS (poll $((POLL_COUNT+1))/$MAX_POLLS)"

    if [ "$STATUS" = "InService" ]; then
        break
    elif [ "$STATUS" = "Failed" ]; then
        log "ERROR: Domain creation failed!"
        exit 1
    fi

    POLL_COUNT=$((POLL_COUNT + 1))
    sleep 15
done

if [ "$STATUS" != "InService" ]; then
    log "ERROR: Domain did not become InService within timeout"
    exit 1
fi

log "Creating user profile: $USER_PROFILE_NAME (with Canvas output path)"

# Ensure the default SageMaker bucket exists (Canvas may need it for working data)
aws s3api create-bucket \
    --bucket "sagemaker-${REGION}-${ACCOUNT_ID}" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --no-cli-pager 2>/dev/null || true

aws sagemaker create-user-profile \
    --domain-id "$DOMAIN_ID" \
    --user-profile-name "$USER_PROFILE_NAME" \
    --user-settings "{\"ExecutionRole\":\"${SAGEMAKER_ROLE_ARN}\",\"CanvasAppSettings\":{\"WorkspaceSettings\":{\"S3ArtifactPath\":\"s3://${S3_BUCKET}/canvas-output\"}}}" \
    --region "$REGION" \
    --no-cli-pager 2>/dev/null || log "  User profile may already exist"

log ""
log "================================================"
log "Studio Domain Ready!"
log "================================================"
log "Domain ID:    $DOMAIN_ID"
log "User Profile: $USER_PROFILE_NAME"
log ""
log "Open Canvas:"
log "  AWS Console → SageMaker → Studio → Open Studio (for canvas-user)"
log "  Then: Canvas → Run Canvas → My models → New model"
log "================================================"
HELPEREOF
chmod +x ${BASE_DIR}/setup_studio.sh

# --- Starter register_model.py (empty template for student) ---
cat > ${BASE_DIR}/register_model_template.py <<'PYEOF'
"""
Model Registration Script — Template
=====================================
Complete this script to register a model version in the SageMaker Model Registry.

Usage:
    python3 register_model.py

Before running, ensure AWS credentials are set as environment variables.
See the lab instructions for details.
"""
import boto3
import json
import os

REGION = "us-west-2"

# Read environment values from lab_env.txt
# Hint: you can parse lab_env.txt or hardcode the values from it
# MODEL_ARTIFACT_URI = "s3://..."
# SKLEARN_IMAGE = "..."

def register_model_version(
    group_name,
    description,
    image_uri,
    model_data_url,
    approval_status="PendingManualApproval"
):
    """
    Register a model version in the SageMaker Model Registry.

    TODO: Complete this function using boto3 sagemaker client.
    - Create a SageMaker client
    - Call create_model_package with the appropriate InferenceSpecification
    - Return the ModelPackageArn
    """
    pass  # Replace with your implementation


if __name__ == "__main__":
    # TODO: Register Version 1 with PendingManualApproval
    # TODO: Print the Model Package ARN
    pass
PYEOF

# --- README ---
cat > ${BASE_DIR}/README.md <<'EOF'
# SageMaker Model Registry Lab

## Quick Start

1. **Set up credentials:**
```bash
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=us-west-2
```

2. **Provision Studio domain:**
```bash
bash setup_studio.sh
```

3. **Create Model Package Group, register models, save details.**

See the lab instructions for full details.
EOF

echo "  ✓ Project files created at ${BASE_DIR}"

# ==========================================
# 6. Save Environment Info
# ==========================================
echo "[6/6] Saving environment info..."

SKLEARN_IMAGE="246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:1.2-1"

cat > /home/user/lab_env.txt <<ENV
REGION=${REGION}
ACCOUNT_ID=${ACCOUNT_ID}
S3_BUCKET=${S3_BUCKET}
MODEL_ARTIFACT_URI=s3://${S3_BUCKET}/models/iris-model.tar.gz
SKLEARN_IMAGE=${SKLEARN_IMAGE}
SAGEMAKER_ROLE_ARN=${ROLE_ARN}
HAS_SESSION_TOKEN=$([ -n "$CRED_TOKEN" ] && echo "yes" || echo "no")
ENV

chown -R user:user ${BASE_DIR}
chown user:user /home/user/lab_env.txt /home/user/aws_iam_creds.json

echo "  ✓ Environment info saved to /home/user/lab_env.txt"

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "  ✓ S3 bucket:     $S3_BUCKET"
echo "  ✓ Model artifact: s3://${S3_BUCKET}/models/iris-model.tar.gz"
echo "  ✓ Iris dataset:   s3://${S3_BUCKET}/datasets/iris.csv"
echo "  ✓ IAM role:       $ROLE_NAME"
echo "  ✓ AWS creds:      /home/user/aws_iam_creds.json"
echo "  ✓ Lab project:    ${BASE_DIR}"
echo "  ✓ Environment:    /home/user/lab_env.txt"
echo ""
echo "  Key values for the lab:"
echo "    SKLEARN_IMAGE       = $SKLEARN_IMAGE"
echo "    MODEL_ARTIFACT_URI  = s3://${S3_BUCKET}/models/iris-model.tar.gz"
echo "    SAGEMAKER_ROLE_ARN  = $ROLE_ARN"
if [ -n "$CRED_TOKEN" ]; then
echo ""
echo "  ⚠ Session token detected — remember to export AWS_SESSION_TOKEN"
fi
echo ""
echo "  Next step: run 'bash setup_studio.sh' to provision the Studio domain"
echo "================================================"
