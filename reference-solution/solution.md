# Reference Solution — Full Student Walkthrough

## Task 1: Provision Studio Domain

```bash
cd /home/user/model-registry-lab
bash setup_studio.sh
# Wait ~5-8 minutes for InService

# Verify:
DOMAIN_ID=$(cat /home/user/domain_id.txt)
aws sagemaker describe-domain \
    --domain-id "$DOMAIN_ID" \
    --region us-west-2 \
    --query 'Status' \
    --output text \
    --no-cli-pager
# Expected: InService
```

## Task 2: Create Model Package Group

```bash
# Set credentials
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=us-west-2
# If session token:
# export AWS_SESSION_TOKEN=$(jq -r '.SessionToken' /home/user/aws_iam_creds.json)

aws sagemaker create-model-package-group \
    --model-package-group-name iris-model-group \
    --model-package-group-description "Iris flower classification model versions for production deployment" \
    --region us-west-2 \
    --no-cli-pager

# Verify:
aws sagemaker describe-model-package-group \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --no-cli-pager
```

## Task 3: Train Model in Canvas

1. AWS Console → SageMaker → Studio → Open Studio (for canvas-user)
2. Canvas → Run Canvas (if stopped) → My models → New model
3. Name: `iris-classifier`, type: Tabular
4. Import data → S3 → select `datasets/iris.csv` from lab bucket
5. Target: `species` column
6. Quick Build → wait ~5-10 minutes

## Task 4: Share Canvas Model to Registry

1. On Canvas model results page → Share → Add to Model Registry
2. Model package group name: `iris-model-group`
3. Click Add/Share

Verify:
```bash
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --no-cli-pager
# Should show 1 version from Canvas
```

## Task 5-6: Register boto3 Model + Approve

Copy the reference `register_model.py` to `/home/user/model-registry-lab/register_model.py` and run:

```bash
cd /home/user/model-registry-lab
python3 register_model.py
```

This registers the boto3 version, approves it, finds the Canvas ARN, and saves registration_details.json.

## Task 7: Verify Everything

```bash
# Both versions listed
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --query 'ModelPackageSummaryList[*].[ModelPackageVersion,ModelApprovalStatus]' \
    --output table \
    --no-cli-pager

# JSON file
cat /home/user/model-registry-lab/registration_details.json | python3 -m json.tool
```
