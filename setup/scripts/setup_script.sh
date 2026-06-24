#!/bin/bash

set -euo pipefail
BASE_DIR="/home/user/sagemaker-iris-lab"
REGION="${AWS_REGION:-us-west-2}"
SETUP_LOG="/home/user/setup_log.txt"

# Log helper — writes to both terminal AND log file
log() {
    echo "$*"
    echo "$*" >> "$SETUP_LOG"
}

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="sagemaker-iris-lab-${ACCOUNT_ID}"

log "================================================"
log "SageMaker Data Preparation Lab - Setup"
log "================================================"
log "Region: ${REGION} | Account: ${ACCOUNT_ID}"
log "Log:    ${SETUP_LOG}"
log ""

# ==========================================
# 1. SageMaker Execution Role
# ==========================================
log "[1/4] Setting up SageMaker execution role..."

ROLE_NAME="sagemaker-lab-execution-role"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

ROLE_EXISTS=$(aws iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.RoleName' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$ROLE_EXISTS" = "NOT_FOUND" ]; then
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document '{
            "Version":"2012-10-17",
            "Statement":[{
                "Effect":"Allow",
                "Principal":{"Service":"sagemaker.amazonaws.com"},
                "Action":"sts:AssumeRole"
            }]
        }' > /dev/null
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
    log "  ✓ Execution role created: $ROLE_ARN"
else
    log "  ✓ Execution role already exists: $ROLE_ARN"
fi

# ==========================================
# 2. Create S3 Bucket
# ==========================================
log "[2/4] Creating S3 bucket..."

BUCKET_EXISTS=$(aws s3api head-bucket --bucket "$BUCKET_NAME" \
    --region "$REGION" 2>&1 || echo "NOT_FOUND")

if echo "$BUCKET_EXISTS" | grep -q "NOT_FOUND"; then
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" \
        > /dev/null
    log "  ✓ Bucket created: $BUCKET_NAME"
else
    log "  ✓ Bucket already exists: $BUCKET_NAME"
fi

aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$REGION" 2>/dev/null || true

# ==========================================
# 3. Upload Iris dataset to S3
# ==========================================
log "[3/4] Uploading Iris dataset to S3..."

mkdir -p "$BASE_DIR"

# Generate iris_raw.csv using pure shell — no python3 required
cat > "$BASE_DIR/iris_raw.csv" << 'CSV'
sepal_length,sepal_width,petal_length,petal_width,species
5.1,3.5,1.4,0.2,setosa
4.9,3.0,1.4,0.2,setosa
4.7,3.2,1.3,0.2,setosa
4.6,3.1,1.5,0.2,setosa
5.0,3.6,1.4,0.2,setosa
5.4,3.9,1.7,0.4,setosa
4.6,3.4,1.4,0.3,setosa
5.0,3.4,1.5,0.2,setosa
4.4,2.9,1.4,0.2,setosa
4.9,3.1,1.5,0.1,setosa
5.4,3.7,1.5,0.2,setosa
4.8,3.4,1.6,0.2,setosa
4.8,3.0,1.4,0.1,setosa
4.3,3.0,1.1,0.1,setosa
5.8,4.0,1.2,0.2,setosa
5.7,4.4,1.5,0.4,setosa
5.4,3.9,1.3,0.4,setosa
5.1,3.5,1.4,0.3,setosa
5.7,3.8,1.7,0.3,setosa
5.1,3.8,1.5,0.3,setosa
5.4,3.4,1.7,0.2,setosa
5.1,3.7,1.5,0.4,setosa
4.6,3.6,1.0,0.2,setosa
5.1,3.3,1.7,0.5,setosa
4.8,3.4,1.9,0.2,setosa
5.0,3.0,1.6,0.2,setosa
5.0,3.4,1.6,0.4,setosa
5.2,3.5,1.5,0.2,setosa
5.2,3.4,1.4,0.2,setosa
4.7,3.2,1.6,0.2,setosa
4.8,3.1,1.6,0.2,setosa
5.4,3.4,1.5,0.4,setosa
5.2,4.1,1.5,0.1,setosa
5.5,4.2,1.4,0.2,setosa
4.9,3.1,1.5,0.2,setosa
5.0,3.2,1.2,0.2,setosa
5.5,3.5,1.3,0.2,setosa
4.9,3.6,1.4,0.1,setosa
4.4,3.0,1.3,0.2,setosa
5.1,3.4,1.5,0.2,setosa
5.0,3.5,1.3,0.3,setosa
4.5,2.3,1.3,0.3,setosa
4.4,3.2,1.3,0.2,setosa
5.0,3.5,1.6,0.6,setosa
5.1,3.8,1.9,0.4,setosa
4.8,3.0,1.4,0.3,setosa
5.1,3.8,1.6,0.2,setosa
4.6,3.2,1.4,0.2,setosa
5.3,3.7,1.5,0.2,setosa
5.0,3.3,1.4,0.2,setosa
7.0,3.2,4.7,1.4,versicolor
6.4,3.2,4.5,1.5,versicolor
6.9,3.1,4.9,1.5,versicolor
5.5,2.3,4.0,1.3,versicolor
6.5,2.8,4.6,1.5,versicolor
5.7,2.8,4.5,1.3,versicolor
6.3,3.3,4.7,1.6,versicolor
4.9,2.4,3.3,1.0,versicolor
6.6,2.9,4.6,1.3,versicolor
5.2,2.7,3.9,1.4,versicolor
5.0,2.0,3.5,1.0,versicolor
5.9,3.0,4.2,1.5,versicolor
6.0,2.2,4.0,1.0,versicolor
6.1,2.9,4.7,1.4,versicolor
5.6,2.9,3.6,1.3,versicolor
6.7,3.1,4.4,1.4,versicolor
5.6,3.0,4.5,1.5,versicolor
5.8,2.7,4.1,1.0,versicolor
6.2,2.2,4.5,1.5,versicolor
5.6,2.5,3.9,1.1,versicolor
5.9,3.2,4.8,1.8,versicolor
6.1,2.8,4.0,1.3,versicolor
6.3,2.5,4.9,1.5,versicolor
6.1,2.8,4.7,1.2,versicolor
6.4,2.9,4.3,1.3,versicolor
6.6,3.0,4.4,1.4,versicolor
6.8,2.8,4.8,1.4,versicolor
6.7,3.0,5.0,1.7,versicolor
6.0,2.9,4.5,1.5,versicolor
5.7,2.6,3.5,1.0,versicolor
5.5,2.4,3.8,1.1,versicolor
5.5,2.4,3.7,1.0,versicolor
5.8,2.7,3.9,1.2,versicolor
6.0,2.7,5.1,1.6,versicolor
5.4,3.0,4.5,1.5,versicolor
6.0,3.4,4.5,1.6,versicolor
6.7,3.1,4.7,1.5,versicolor
6.3,2.3,4.4,1.3,versicolor
5.6,3.0,4.1,1.3,versicolor
5.5,2.5,4.0,1.3,versicolor
5.5,2.6,4.4,1.2,versicolor
6.1,3.0,4.6,1.4,versicolor
5.8,2.6,4.0,1.2,versicolor
5.0,2.3,3.3,1.0,versicolor
5.6,2.7,4.2,1.3,versicolor
5.7,3.0,4.2,1.2,versicolor
5.7,2.9,4.2,1.3,versicolor
6.2,2.9,4.3,1.3,versicolor
5.1,2.5,3.0,1.1,versicolor
5.7,2.8,4.1,1.3,versicolor
6.3,3.3,6.0,2.5,virginica
5.8,2.7,5.1,1.9,virginica
7.1,3.0,5.9,2.1,virginica
6.3,2.9,5.6,1.8,virginica
6.5,3.0,5.8,2.2,virginica
7.6,3.0,6.6,2.1,virginica
4.9,2.5,4.5,1.7,virginica
7.3,2.9,6.3,1.8,virginica
6.7,2.5,5.8,1.8,virginica
7.2,3.6,6.1,2.5,virginica
6.5,3.2,5.1,2.0,virginica
6.4,2.7,5.3,1.9,virginica
6.8,3.0,5.5,2.1,virginica
5.7,2.5,5.0,2.0,virginica
5.8,2.8,5.1,2.4,virginica
6.4,3.2,5.3,2.3,virginica
6.5,3.0,5.5,1.8,virginica
7.7,3.8,6.7,2.2,virginica
7.7,2.6,6.9,2.3,virginica
6.0,2.2,5.0,1.5,virginica
6.9,3.2,5.7,2.3,virginica
5.6,2.8,4.9,2.0,virginica
7.7,2.8,6.7,2.0,virginica
6.3,2.7,4.9,1.8,virginica
6.7,3.3,5.7,2.1,virginica
7.2,3.2,6.0,1.8,virginica
6.2,2.8,4.8,1.8,virginica
6.1,3.0,4.9,1.8,virginica
6.4,2.8,5.6,2.1,virginica
7.2,3.0,5.8,1.6,virginica
7.4,2.8,6.1,1.9,virginica
7.9,3.8,6.4,2.0,virginica
6.4,2.8,5.6,2.2,virginica
6.3,2.8,5.1,1.5,virginica
6.1,2.6,5.6,1.4,virginica
7.7,3.0,6.1,2.3,virginica
6.3,3.4,5.6,2.4,virginica
6.4,3.1,5.5,1.8,virginica
6.0,3.0,4.8,1.8,virginica
6.9,3.1,5.4,2.1,virginica
6.7,3.1,5.6,2.4,virginica
6.9,3.1,5.1,2.3,virginica
5.8,2.7,5.1,1.9,virginica
6.8,3.2,5.9,2.3,virginica
6.7,3.3,5.7,2.5,virginica
6.7,3.0,5.2,2.3,virginica
6.3,2.5,5.0,1.9,virginica
6.5,3.0,5.2,2.0,virginica
6.2,3.4,5.4,2.3,virginica
5.9,3.0,5.1,1.8,virginica
CSV

log "  iris_raw.csv created: 150 rows"

aws s3 cp "$BASE_DIR/iris_raw.csv" \
    "s3://${BUCKET_NAME}/raw-data/iris_raw.csv" \
    --region "$REGION" > /dev/null

log "  ✓ iris_raw.csv uploaded → s3://${BUCKET_NAME}/raw-data/iris_raw.csv"

# ==========================================
# 4. Save credentials + env info + helpers
# ==========================================
log "[4/4] Saving credentials, environment info, and helper scripts..."

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
    log "  ERROR: Could not extract AWS credentials"
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
    log "  ✓ Credentials saved with session token"
else
    cat > /home/user/aws_iam_creds.json <<CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}"
}
CREDS
    log "  ✓ Credentials saved"
fi
chmod 600 /home/user/aws_iam_creds.json

# Helper script for uploading the .flow file
cat > "$BASE_DIR/upload_flow.sh" <<UPLOADSCRIPT
#!/bin/bash
# Usage: ./upload_flow.sh <path-to-your-flow-file>
# Uploads your Data Wrangler .flow file to the lab S3 bucket.
# The destination is always flows/iris_flow.flow — do not change this.

FLOW_FILE="\${1:-}"
if [ -z "\$FLOW_FILE" ]; then
    echo "Usage: ./upload_flow.sh <path-to-your-flow-file>"
    echo "Example: ./upload_flow.sh my_iris_flow.flow"
    exit 1
fi

if [ ! -f "\$FLOW_FILE" ]; then
    echo "Error: File not found: \$FLOW_FILE"
    exit 1
fi

BUCKET="${BUCKET_NAME}"
REGION="${REGION}"

echo "Uploading \$FLOW_FILE → s3://\${BUCKET}/flows/iris_flow.flow ..."
aws s3 cp "\$FLOW_FILE" "s3://\${BUCKET}/flows/iris_flow.flow" --region "\$REGION"
echo "Done! Verify with:"
echo "  aws s3 ls s3://\${BUCKET}/flows/"
UPLOADSCRIPT
chmod +x "$BASE_DIR/upload_flow.sh"

# Helper script for students to set up Studio themselves
# (Domain + user profile creation is a student task — see SETUP_DOMAIN_NOTE below)
cat > "$BASE_DIR/setup_studio.sh" <<STUDIOSETUP
#!/bin/bash
# Run this ONCE to create your SageMaker Studio domain and user profile.
# This takes ~5 minutes. Run it first, then open Studio via the Console.

REGION="us-west-2"
ROLE_ARN="${ROLE_ARN}"
BUCKET="${BUCKET_NAME}"

echo "================================================"
echo " Setting up SageMaker Studio"
echo "================================================"

# Get VPC details
VPC_ID=\$(aws ec2 describe-vpcs \\
    --filters Name=is-default,Values=true \\
    --region "\$REGION" \\
    --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=\$(aws ec2 describe-subnets \\
    --filters "Name=vpc-id,Values=\$VPC_ID" \\
    --region "\$REGION" \\
    --query 'Subnets[0].SubnetId' --output text)

echo "  Using VPC: \$VPC_ID  Subnet: \$SUBNET_ID"

# Create domain
echo "  Creating Studio domain (this takes ~5 min, please wait)..."
DOMAIN_OUTPUT=\$(aws sagemaker create-domain \\
    --domain-name "iris-lab-domain" \\
    --auth-mode IAM \\
    --default-user-settings "{\\"ExecutionRole\\":\\"\$ROLE_ARN\\"}" \\
    --vpc-id "\$VPC_ID" \\
    --subnet-ids "\$SUBNET_ID" \\
    --region "\$REGION" 2>&1 || true)

DOMAIN_ID=\$(echo "\$DOMAIN_OUTPUT" | grep -o 'd-[a-z0-9A-Z]*' | head -1)
if [ -z "\$DOMAIN_ID" ]; then
    echo "  ERROR: Could not get domain ID. Output was:"
    echo "\$DOMAIN_OUTPUT"
    exit 1
fi
echo "  Domain ID: \$DOMAIN_ID"

# Wait for InService
echo "  Waiting for domain to become InService..."
WAITED=0
while [ \$WAITED -lt 30 ]; do
    STATUS=\$(aws sagemaker describe-domain \\
        --domain-id "\$DOMAIN_ID" \\
        --region "\$REGION" \\
        --query 'Status' --output text 2>/dev/null || echo "Unknown")
    echo "    Status: \$STATUS"
    if [ "\$STATUS" = "InService" ]; then
        echo "  ✓ Domain is InService!"
        break
    fi
    sleep 10
    WAITED=\$((WAITED + 1))
done

if [ "\$STATUS" != "InService" ]; then
    echo "  WARNING: Domain not yet InService after 5 min. Check AWS Console."
fi

# Get IAM username for profile name
CALLER_ARN=\$(aws sts get-caller-identity --query 'Arn' --output text)
IAM_USERNAME=\$(echo "\$CALLER_ARN" | cut -d'/' -f2)
PROFILE_NAME=\$(echo "\$IAM_USERNAME" | tr '_.' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-63)

aws sagemaker create-user-profile \\
    --domain-id "\$DOMAIN_ID" \\
    --user-profile-name "\$PROFILE_NAME" \\
    --user-settings "{\\"ExecutionRole\\":\\"\$ROLE_ARN\\"}" \\
    --region "\$REGION" > /dev/null 2>&1 || true

echo "  ✓ User profile: \$PROFILE_NAME"
echo ""
echo "  Studio domain is ready. Open via AWS Console:"
echo "  https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/studio"
echo ""
echo "  Your bucket: \$BUCKET"
echo "================================================"
STUDIOSETUP
chmod +x "$BASE_DIR/setup_studio.sh"

cat > /home/user/lab_env.txt <<ENV
REGION=${REGION}
ACCOUNT_ID=${ACCOUNT_ID}
BUCKET_NAME=${BUCKET_NAME}
SAGEMAKER_ROLE_ARN=${ROLE_ARN}
RAW_DATA_S3=s3://${BUCKET_NAME}/raw-data/iris_raw.csv
FLOW_OUTPUT_S3=s3://${BUCKET_NAME}/flows/iris_flow.flow
PROCESSED_OUTPUT_S3_PREFIX=s3://${BUCKET_NAME}/processed-data/
SAGEMAKER_STUDIO_URL=https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/studio
IMPORTANT=Always use us-west-2 region in the AWS Console
ENV

chown -R user:user "$BASE_DIR"
chown user:user /home/user/lab_env.txt /home/user/aws_iam_creds.json

log "  ✓ AWS credentials:  /home/user/aws_iam_creds.json"
log "  ✓ Environment info: /home/user/lab_env.txt"
log "  ✓ Upload helper:    $BASE_DIR/upload_flow.sh"
log "  ✓ Studio setup:     $BASE_DIR/setup_studio.sh"

log ""
log "================================================"
log "Setup Complete!"
log "================================================"
log ""
log "  ✓ Execution role: $ROLE_ARN"
log "  ✓ S3 bucket:      $BUCKET_NAME"
log "  ✓ Raw dataset:    s3://${BUCKET_NAME}/raw-data/iris_raw.csv"
log "  ✓ AWS creds:      /home/user/aws_iam_creds.json"
log ""
log "  NEXT STEP: Run the Studio setup script:"
log "    cd ~/sagemaker-iris-lab && bash setup_studio.sh"
log ""
log "  This creates the Studio domain (~5 min) and your user profile."
log "  Then open Studio at the URL in lab_env.txt."
log ""
log "================================================"

echo "SETUP_STATUS=complete" >> /home/user/lab_env.txt
echo "SETUP_COMPLETED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /home/user/lab_env.txt
chown user:user /home/user/lab_env.txt
