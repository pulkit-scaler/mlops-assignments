# SageMaker Model Registry and Canvas — Lab Question

---

## Description

In this lab, you will work with the **AWS SageMaker Model Registry** to manage ML model versions through a formal approval workflow, and use **SageMaker Canvas** to build a no-code model and share it directly into the registry.

The SageMaker Model Registry is a central hub for cataloging trained ML models, tracking versions, managing approval workflows, and associating metadata such as training metrics and inference specifications. It is a critical component of production MLOps pipelines where model governance and reproducibility are required.

You will:

- Provision a SageMaker Studio domain and use Canvas for no-code model training
- Create a **Model Package Group** to organize model versions using the AWS CLI
- Train an Iris classifier in Canvas and **share it to the Model Registry** directly from the Canvas UI
- Register an additional model version programmatically using **boto3**, specifying inference containers and model artifacts
- Manage the **approval workflow** by transitioning a model from `PendingManualApproval` to `Approved`
- Save structured registration details for audit and downstream automation

This lab simulates a real-world MLOps scenario where models arrive in the registry from multiple sources — no-code tools like Canvas and programmatic pipelines — and are governed through a centralized approval process.

---

## Prerequisites

The following resources are pre-provisioned and available to you in `us-west-2`:

- **AWS Account** with:
    - An S3 bucket containing a pre-trained Iris classifier model artifact (`iris-model.tar.gz`)

    - An S3 bucket containing the Iris dataset CSV for Canvas import

    - An IAM execution role for SageMaker (`SageMakerLabExecutionRole`)

- **Pre-created Files on Your Machine:**

  - `/home/user/aws_iam_creds.json` — AWS access keys (AccessKeyId and SecretAccessKey, and optionally SessionToken)

  - `/home/user/lab_env.txt` — All environment details (source this for reference values)

  - `/home/user/model-registry-lab/` — Lab working directory with starter files

  - `/home/user/model-registry-lab/setup_studio.sh` — Helper script to provision SageMaker Studio domain

---

## Important Notes

- All AWS CLI commands in this lab should include `--no-cli-pager` to avoid pager issues.

- Use `python3` and `python3 -m pip` for all Python operations — never bare `pip` or `pip3`.

- Before running any Python scripts or AWS CLI commands, set up your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=us-west-2
```

If your credentials include a session token (`/home/user/lab_env.txt` shows `HAS_SESSION_TOKEN=yes`), also run:

```bash
export AWS_SESSION_TOKEN=$(jq -r '.SessionToken' /home/user/aws_iam_creds.json)
```

---

## Tasks

### 1. Provision SageMaker Studio Domain

A helper script is provided to create the SageMaker Studio domain. This step takes approximately **5–8 minutes** — the script will poll and wait for the domain to become active.

```bash
cd /home/user/model-registry-lab
bash setup_studio.sh
```

The script will display progress and save the domain ID to `/home/user/domain_id.txt`. Wait for the message confirming the domain is `InService` before proceeding.

**Verify the domain is ready:**

```bash
DOMAIN_ID=$(cat /home/user/domain_id.txt)
aws sagemaker describe-domain \
    --domain-id "$DOMAIN_ID" \
    --region us-west-2 \
    --query 'Status' \
    --output text \
    --no-cli-pager
```

This should return `InService`.

---

### 2. Create a Model Package Group

Using the AWS CLI on your container, create a Model Package Group that will hold all your registered model versions — both from Canvas and from boto3.

**This step must be completed before sharing your Canvas model in Task 4.**

**Requirements:**

- **Group name:** `iris-model-group`
- **Description:** `Iris flower classification model versions for production deployment`

Use the `aws sagemaker create-model-package-group` command.

> **Hint:** Check the [AWS CLI reference for create-model-package-group](https://docs.aws.amazon.com/cli/latest/reference/sagemaker/create-model-package-group.html) for the exact syntax.

**Verify the group was created:**

```bash
aws sagemaker describe-model-package-group \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --no-cli-pager
```

You should see your group with status `Completed`.

---

### 3. Train a Model in SageMaker Canvas

Open Canvas and build a no-code Iris classifier.

**Navigate to Canvas:**

1. Open the **AWS Console** and navigate to SageMaker. If you land on the new "Amazon SageMaker Unified Studio" page, click the **"Artificial Intelligence & Machine Learning"** card to reach the classic SageMaker console. Alternatively, go directly to:
   ```
   https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/studio
   ```

2. Under **Admin configurations** → **Domains**, find your domain `canvas-lab-domain`

3. Click **Open Studio** next to the `canvas-user` profile

4. In Studio, locate the **Canvas** application in the left sidebar. If it shows **Status: Stopped**, click **Run Canvas** and wait ~1–2 minutes for it to start

**Create a new model:**

1. Once Canvas opens, click **My models** → **New model**
2. Name your model `iris-classifier`
3. Select **Predictive analysis** as the problem type
4. Click **Create**

**Import the Iris dataset:**

1. On the dataset selection screen, you will see Canvas sample datasets — your Iris file is not among them yet
2. Click **+ Create dataset** (top-right corner)
3. In the dialog, set the dataset name to `iris` and click **Create**
4. Choose **Amazon S3** as the data source
5. Navigate to your lab bucket (check `S3_BUCKET` in `/home/user/lab_env.txt`) and select `datasets/iris.csv`
6. Complete the import — the `iris` dataset should appear in the list with 5 columns, 150 rows, status Ready
7. Select it and click **Select dataset**

**Configure and train:**

1. Select the **`species`** column as the **Target column**
2. Choose **Quick build** (faster, sufficient for this lab — takes approximately 5–10 minutes)
3. Wait for training to complete — you should see an accuracy metric (typically ~96-97% for Iris)

> **Note:** Canvas bills per hour while running. The platform's Stop Lab button will terminate everything when you're done.

---

### 4. Share Canvas Model to Model Registry

After your Canvas model finishes training and shows the Analyze results page:

1. Click the **three-dot menu (⋮)** in the top-right corner of the page (next to the clock icon and "Create new version" button)
2. Select **"Add to Model Registry"**
3. In the sharing dialog:
   - It shows the selected version as **V1 Ready**
   - The **Model group name** field will be pre-filled with a Canvas-generated name — **clear it** and type exactly: `iris-model-group`
   - This must match the group you created in Task 2
4. Click **Add**

**Verify the Canvas model appears in the registry:**

```bash
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --no-cli-pager
```

You should see one model package version with status `Completed`. Note its ARN — you will need it for the registration details file.

---

### 5. Register a Model Version via boto3

Write a Python script at `/home/user/model-registry-lab/register_model.py` that registers an additional model version in the `iris-model-group` using the pre-trained sklearn model artifact.

The script must use the **boto3** SageMaker client to call `create_model_package` with the following specification:

**Inference Specification:**

- **Container image:** Use the pre-built SageMaker scikit-learn inference container. The full URI is available in `/home/user/lab_env.txt` as `SKLEARN_IMAGE`.

- **Model data URL:** The pre-trained model artifact in S3. The full URI is available in `/home/user/lab_env.txt` as `MODEL_ARTIFACT_URI`.

- **Supported content types:** `text/csv` and `application/json`

- **Supported response MIME types:** `application/json`

- **Supported real-time inference instance types:** `ml.t2.medium` and `ml.m5.large`

- **Supported transform instance types:** `ml.m5.large`

**Other parameters:**

- **Model Package Group:** `iris-model-group`
- **Model Package Description:** `Iris classifier - scikit-learn Random Forest baseline`
- **Model Approval Status:** `PendingManualApproval`

**Run your script:**

```bash
cd /home/user/model-registry-lab
python3 register_model.py
```

The script should print the created Model Package ARN. Save it — you will need it for the next steps.

**Verify both versions are now listed:**

```bash
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --query 'ModelPackageSummaryList[*].[ModelPackageVersion,ModelApprovalStatus]' \
    --output table \
    --no-cli-pager
```

You should see two model package versions — one from Canvas and one from your boto3 script.

---

### 6. Approve the boto3-Registered Model

Update the approval status of your boto3-registered model from `PendingManualApproval` to `Approved`. You can do this via the AWS CLI:

```bash
aws sagemaker update-model-package \
    --model-package-arn "<YOUR_BOTO3_MODEL_PACKAGE_ARN>" \
    --model-approval-status Approved \
    --region us-west-2 \
    --no-cli-pager
```

Replace `<YOUR_BOTO3_MODEL_PACKAGE_ARN>` with the ARN printed by your registration script.

**Verify the approval:**

```bash
aws sagemaker describe-model-package \
    --model-package-name "<YOUR_BOTO3_MODEL_PACKAGE_ARN>" \
    --region us-west-2 \
    --query 'ModelApprovalStatus' \
    --output text \
    --no-cli-pager
```

This should return `Approved`.

---

### 7. Save Registration Details

Create a JSON file at `/home/user/model-registry-lab/registration_details.json` with the following structure. Populate it with the **actual values** from your registered models:

```json
{
  "model_package_group_name": "iris-model-group",
  "canvas_model_package_arn": "<ARN_of_canvas_shared_version>",
  "boto3_model_package_arn": "<ARN_of_boto3_registered_version>",
  "boto3_approval_status": "Approved",
  "inference_image": "<sklearn_container_image_URI>",
  "model_data_url": "<S3_model_artifact_URI>",
  "total_versions": 2
}
```

To find the Canvas model's ARN, list all packages and identify the one you did **not** register via boto3:

```bash
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --query 'ModelPackageSummaryList[*].[ModelPackageArn,ModelPackageVersion]' \
    --output table \
    --no-cli-pager
```

You can create this file manually or have your Python script generate it. All ARN and URI values must be real — the test scripts will validate them against AWS.

---

## Verification Checklist

Before submitting, confirm the following:

```bash
# 1. Studio domain is active
cat /home/user/domain_id.txt

# 2. Model Package Group exists
aws sagemaker describe-model-package-group \
    --model-package-group-name iris-model-group \
    --region us-west-2 --no-cli-pager

# 3. Both model versions are registered (Canvas + boto3)
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 --no-cli-pager

# 4. At least one version is Approved
aws sagemaker list-model-packages \
    --model-package-group-name iris-model-group \
    --region us-west-2 \
    --query 'ModelPackageSummaryList[?ModelApprovalStatus==`Approved`]' \
    --no-cli-pager

# 5. Registration details file exists and is valid
cat /home/user/model-registry-lab/registration_details.json | python3 -m json.tool
```

---

## Your work must include:

- A provisioned SageMaker Studio domain in `InService` state with Canvas having been launched

- A Model Package Group named `iris-model-group`

- A Canvas-trained model shared to the `iris-model-group` via the Canvas UI

- A boto3-registered model version in the same group with a valid scikit-learn inference specification

- At least one model version with approval status `Approved`

- A `registration_details.json` file at `/home/user/model-registry-lab/registration_details.json` with the correct structure and real values

---

## Outcomes

When completed correctly:

- The SageMaker Studio domain is provisioned and Canvas was used to train a model

- A Model Package Group named `iris-model-group` contains versions from **two different sources**: Canvas (no-code) and boto3 (programmatic)

- The Canvas-shared model uses an AutoML-generated inference container, while the boto3-registered model uses the standard SageMaker scikit-learn container — demonstrating that the registry can unify models regardless of origin

- The approval workflow is demonstrated — the boto3 version transitions from `PendingManualApproval` to `Approved`

- A structured `registration_details.json` captures all registration metadata for audit purposes

**Skills practiced:**

- SageMaker Studio and Canvas provisioning and navigation
- No-code ML model building and sharing with Canvas
- Model Package Group creation and management via AWS CLI
- Programmatic model registration with boto3
- Model approval workflow management
- Inference specification configuration (container images, model artifacts, instance types)
- Multi-source model registry governance (Canvas + programmatic)
- Structured metadata capture for MLOps audit trails
