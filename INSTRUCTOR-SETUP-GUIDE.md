# SageMaker Model Registry + Canvas Lab — Instructor Setup Guide

## 1. Platform Configuration

| Setting | Value |
|---|---|
| **Setup file** | `Setup.zip` |
| **Test Case Zip** | `TestCase.zip` |
| **Max Score** | 50 |
| **Time Limit** | 40 minutes |
| **Duration** | 90 minutes |

> **Duration note:** This lab is 90 minutes because provisioning the SageMaker Studio domain takes ~5–8 minutes, and Canvas Quick Build training takes ~5–10 minutes. Students need extra time for console navigation.

### AWS Policies to Select

- ✅ **SageMaker Policy** (or equivalent providing `sagemaker:*` in us-west-2)
- ✅ **DSML playground policy** (provides `ec2:*`, `s3:*`, `sts:*`, `iam:CreateRole`, `iam:PutRolePolicy`, `iam:PassRole`)

**Minimum permissions needed:**

| Category | Actions |
|---|---|
| SageMaker | `sagemaker:CreateDomain`, `sagemaker:DescribeDomain`, `sagemaker:DescribeApp`, `sagemaker:CreateUserProfile`, `sagemaker:CreateApp`, `sagemaker:CreateModelPackageGroup`, `sagemaker:DescribeModelPackageGroup`, `sagemaker:CreateModelPackage`, `sagemaker:DescribeModelPackage`, `sagemaker:UpdateModelPackage`, `sagemaker:ListModelPackages` |
| IAM | `iam:CreateRole`, `iam:PutRolePolicy`, `iam:PassRole`, `iam:GetRole` |
| S3 | `s3:CreateBucket`, `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`, `s3:GetBucketAcl`, `s3:GetBucketLocation`, `s3:AbortMultipartUpload`, `s3:GetBucketCors`, `s3:PutBucketCors` |
| STS | `sts:GetCallerIdentity` |
| EC2 (for Studio VPC) | `ec2:DescribeVpcs`, `ec2:DescribeSubnets`, `ec2:DescribeSecurityGroups` |

### Policy Constraints Handled

| Constraint | How We Handle It |
|---|---|
| `sagemaker:ListDomains` blocked | Helper script uses `create + suppress error` — no list calls |
| `sagemaker:ListApps` may be blocked | Test 01 uses `describe-app` with known parameters, not `list-apps` |
| IAM role deletion may be blocked | No cleanup in test scripts; platform Stop Lab handles teardown |
| Canvas costs ~$1.90/hr | Stop Lab terminates everything |

---

## 2. Timing

| Phase | Target |
|---|---|
| **Setup script** | ~60-90 sec (S3 bucket + model artifact + IAM role, no domain wait) |
| **Studio domain provisioning** | ~5-8 min (student runs helper script as Task 1) |
| **Canvas startup** | ~1-2 min (student clicks Run Canvas) |
| **Canvas Quick Build training** | ~5-10 min (Iris dataset is tiny) |
| **Canvas → Registry sharing** | ~1 min (UI operation) |
| **CLI/boto3 work** | ~15-20 min |
| **Test scripts** | ~20-30 sec (AWS API calls only) |

---

## 3. What the Setup Script Creates

| Resource | Details |
|---|---|
| Python + boto3 + sklearn | Installed on container for student scripts |
| S3 Bucket (lab) | `sagemaker-registry-lab-{ACCOUNT_ID}` |
| S3 Bucket (SageMaker default) | `sagemaker-{REGION}-{ACCOUNT_ID}` (created by helper script for Canvas working data) |
| Model Artifact | `s3://{lab-bucket}/models/iris-model.tar.gz` (real trained sklearn model) |
| Iris Dataset CSV | `s3://{lab-bucket}/datasets/iris.csv` (for Canvas import) |
| IAM Execution Role | `SageMakerLabExecutionRole` with S3, SageMaker, ECR, IAM PassRole permissions |
| AWS Credentials | Container's own creds → `/home/user/aws_iam_creds.json` |
| Helper Script | `/home/user/model-registry-lab/setup_studio.sh` (creates domain + user profile with Canvas S3 output path) |
| Starter Template | `/home/user/model-registry-lab/register_model_template.py` |
| Environment Info | `/home/user/lab_env.txt` |

**No SageMaker domain in setup.** Domain provisioning is too slow (~5-8 min) for the setup timeout.

---

## 4. Test Cases (50 pts)

| # | Pts | What It Tests | Student Action Verified |
|---|---|---|---|
| 01 | 5 | Studio domain InService + Canvas app launched | Student ran helper + opened Canvas |
| 02 | 5 | Model Package Group `iris-model-group` exists | Student created group via CLI |
| 03 | 5 | Canvas-originated model found in group | Student shared Canvas model to registry |
| 04 | 5 | boto3-registered model with sklearn container found | Student ran register_model.py |
| 05 | 5 | boto3 model has correct S3 model data URL | Student configured correct artifact path |
| 06 | 5 | boto3 model has content types + instance types | Student configured full inference spec |
| 07 | 5 | At least 1 version with Approved status | Student ran approval update |
| 08 | 5 | `registration_details.json` exists and is valid JSON | Student created output file |
| 09 | 5 | JSON has all required fields with valid values | Student populated with real ARNs |
| 10 | 5 | ≥2 total model versions in group | Canvas + boto3 both present |

### How Test 03 (Canvas Model) Works

Test 03 iterates through all model packages in `iris-model-group` and describes each one. It looks for a model package whose `InferenceSpecification.Containers[0].Image` does **not** contain `sagemaker-scikit-learn`. Canvas uses AutoML containers (e.g. `autogluon-inference`, `sagemaker-autopilot-*`, or `sagemaker-xgboost-*`) which are distinct from the sklearn container students use for boto3 registration.

**Why this works:** The lab explicitly tells students to use the `sagemaker-scikit-learn` container for their boto3 registration (Task 5). Any model with a different container must have come from Canvas. Test 01 independently verifies the Canvas app was opened via `describe-app`.

### Test Dependencies / State Sharing

Scripts run sequentially. State sharing via `/var/tmp/`:

| Script | Saves |
|---|---|
| 01 | `/var/tmp/domain_id.txt` |
| 02 | `/var/tmp/model_package_group.json` |
| 03 | `/var/tmp/model_packages_list.json`, `/var/tmp/canvas_model_detail.json`, `/var/tmp/canvas_model_arn.txt` |
| 04 | `/var/tmp/sklearn_model_detail.json`, `/var/tmp/sklearn_model_arn.txt` |
| 08 | `/var/tmp/registration_details.json` |

If an early test fails, later tests independently attempt to fetch the required information from AWS, so partial credit is possible.

---

## 5. Session Token Note

If the platform provides temporary STS credentials, the setup script detects the session token and saves it in `/home/user/aws_iam_creds.json`. The lab instructions tell students to check `HAS_SESSION_TOKEN` in `lab_env.txt` and export `AWS_SESSION_TOKEN` if needed.

---

## 6. Canvas Cost Note

Canvas bills ~$1.90/hour while the app is running. The platform's **Stop Lab** button terminates the entire sandbox, stopping all billing.

---

## 7. Key Environment Variables in `lab_env.txt`

| Variable | Example Value | Purpose |
|---|---|---|
| `REGION` | `us-west-2` | AWS region |
| `ACCOUNT_ID` | `123456789012` | AWS account |
| `S3_BUCKET` | `sagemaker-registry-lab-123456789012` | Lab S3 bucket |
| `MODEL_ARTIFACT_URI` | `s3://sagemaker-registry-lab-.../models/iris-model.tar.gz` | Pre-trained model |
| `SKLEARN_IMAGE` | `246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:1.2-1` | SageMaker inference container |
| `SAGEMAKER_ROLE_ARN` | `arn:aws:iam::123456789012:role/SageMakerLabExecutionRole` | Execution role for domain |
| `HAS_SESSION_TOKEN` | `yes` / `no` | Whether student needs to export session token |

---

## 8. Canvas UI Navigation — Live-Tested Notes (June 2026)

These notes reflect the actual Canvas UI observed during live testing and should be kept current.

### SageMaker Console Landing Page

The AWS console for SageMaker now defaults to the **"Amazon SageMaker Unified Studio"** landing page. Students must click the **"Artificial Intelligence & Machine Learning"** card to reach the classic SageMaker console where Studio domains are managed. Alternatively, navigate directly to:
```
https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/studio
```

### Canvas Dataset Import

Canvas shows pre-loaded sample datasets (retail forecasting, loans, shipping logs, etc.) on the dataset selection screen. The student's Iris file is **not** in this list. Students must:
1. Click **+ Create dataset** (top-right)
2. Name it `iris`, click **Create**
3. Select **Amazon S3** as source
4. Browse to `s3://{bucket}/datasets/iris.csv`

### Canvas Model Training

- Problem type: **Predictive analysis** (the first card, pre-selected)
- Target column: **species**
- Quick Build produces ~96.667% accuracy on Iris (typical result)
- Training takes approximately 5-10 minutes

### Canvas → Model Registry Sharing

- The "Add to Model Registry" option is under the **three-dot menu (⋮)** in the top-right corner of the Analyze results page
- The dialog shows the version (V1 Ready), and a **Model group name** field
- The field is **pre-filled** with a Canvas-generated name (e.g., `canvas-iris-classifier`) — students must **clear it and type `iris-model-group`** exactly
- Click **Add** to complete

---

## 9. Bugs Fixed During Live Testing

### Canvas "Invalid Output Path" Error (FIXED in current Setup.zip)

**Symptom:** Canvas opens but immediately shows "Invalid output path. Your output path is invalid or you don't have permissions to use it."

**Root cause:** The original `setup_studio.sh` helper created the user profile without `CanvasAppSettings.WorkspaceSettings.S3ArtifactPath`, so Canvas had no valid S3 location for its output.

**Fix applied (two parts):**

1. **Helper script (`setup_studio.sh`):** User profile creation now includes Canvas settings:
   ```bash
   aws sagemaker create-user-profile \
       --user-settings '{"ExecutionRole":"...","CanvasAppSettings":{"WorkspaceSettings":{"S3ArtifactPath":"s3://{bucket}/canvas-output"}}}'
   ```

2. **IAM role policy:** Broadened to include:
   - The default SageMaker bucket (`sagemaker-{region}-{account}`) for Canvas working data
   - Additional S3 actions Canvas needs: `AbortMultipartUpload`, `GetBucketCors`, `PutBucketCors`
   - `iam:GetRole` and `iam:PassRole` for Canvas to assume the execution role

3. **Default SageMaker bucket:** The helper script now pre-creates `sagemaker-{region}-{account}` before creating the user profile.

---

## 10. Troubleshooting

### Studio domain creation fails
- **Cause:** IAM role not yet available (eventual consistency), or VPC/subnet issues
- **Fix:** Wait 30 seconds and re-run `setup_studio.sh` — it's idempotent

### Canvas "Share" / "Add to Model Registry" not visible
- **Cause:** Student is not on the Analyze results page, or training is not yet complete
- **Fix:** Wait for training to finish (accuracy metric visible). The option is under the three-dot menu (⋮) at the top-right of the Analyze page

### Canvas share says "Model Package Group not found"
- **Cause:** Student tried to share before creating the group in Task 2, or typed the name wrong
- **Fix:** Create the group via CLI first, use exactly `iris-model-group`

### Canvas pre-fills wrong group name
- **Cause:** Canvas auto-generates a group name based on the Canvas model name
- **Fix:** Clear the pre-filled value and type `iris-model-group` exactly

### `create-model-package-group` access denied
- **Cause:** Missing SageMaker policy
- **Fix:** Verify the SageMaker policy is selected in the platform

### boto3 `NoCredentialsError`
- **Cause:** Student forgot to export AWS environment variables
- **Fix:** Run the credential export commands from the lab instructions

### `create_model_package` ValidationException
- **Possible causes:** Missing required fields in InferenceSpecification, invalid container URI format, invalid S3 URI for ModelDataUrl
- **Fix:** Verify all fields match the lab instructions

### Test 03 fails even though Canvas model was shared
- **Possible cause:** Canvas used a scikit-learn-based AutoML pipeline (rare edge case)
- **Fix:** Examine the actual container image in the Canvas model package. If it truly contains "sagemaker-scikit-learn", the test may need to also check `ModelDataUrl` patterns (Canvas model data URLs point to autopilot output paths, not the lab's `models/iris-model.tar.gz`)

---

## 11. Reference Solution

The reference solution is at `reference/register_model.py` and `reference/SOLUTION_WALKTHROUGH.md`.

The student's critical deliverables:
1. Run `setup_studio.sh` → domain InService, open Canvas (Test 01)
2. Run `aws sagemaker create-model-package-group` → group exists (Test 02)
3. Train in Canvas + Share to Model Registry → Canvas model in group (Test 03)
4. Write and run `register_model.py` → sklearn model in group (Tests 04-06)
5. Approve boto3 version (Test 07)
6. Create `registration_details.json` with real ARNs (Tests 08-09)
7. Both versions present (Test 10)
