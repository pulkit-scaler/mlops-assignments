# Feature Store: Ingest and Retrieve — Instructor Setup Guide

## 1. Platform Configuration

- **Setup file:** `Setup.zip`
- **Test Case Zip:** `TestCase.zip`
- **Max Score:** 50
- **Time Limit:** 40 minutes
- **Duration:** 75 minutes
- **Container OS:** Ubuntu (recommended)

### AWS Policy to Select

- **DSML playground policy** (provides `sagemaker:*`, `s3:*`, `sts:*` in us-west-2)

The setup script makes these AWS API calls:
- `sts:GetCallerIdentity` — get account ID
- `s3:CreateBucket`, `s3:HeadBucket` — create the offline store bucket

The test scripts make these calls:
- `sts:GetCallerIdentity` — credential validation
- `sagemaker:DescribeFeatureGroup` — verify feature group the student created
- `s3:ListObjectsV2` — verify offline store has data after ingestion

All covered by the DSML playground policy. No IAM user creation needed.

---

## 2. Why CLI Instead of Console for Feature Group Creation

The original design used the SageMaker Studio console to create the feature group. This was changed because:

- `sagemaker:ListDomains` is blocked by the DSML policy, which causes the Studio console to throw an `AccessDeniedException` on load
- Studio requires a SageMaker domain to be provisioned first (~5–8 min), which is outside the lab scope

The AWS CLI is a direct replacement — it exercises the same `sagemaker:CreateFeatureGroup` API call and teaches the same configuration choices (feature definitions, record identifier, event time, online/offline store). Students still have to understand and specify every parameter themselves.

---

## 3. Timing

- **Setup script:** ~30–60 sec (S3 bucket creation only)
- **Test scripts:** ~15–25 sec
- **Student work:** ~50–65 min (create feature group via CLI, write + run script, verify output)

---

## 4. What the Setup Script Creates

- **S3 Bucket:** `feature-store-lab-<ACCOUNT_ID>` in us-west-2
- **IAM Role:** `SageMakerFeatureStoreRole` — trust policy allows `sagemaker.amazonaws.com` to assume it; inline policy scoped to S3 read/write on the lab bucket only
- **AWS Credentials:** `/home/user/aws_iam_creds.json`
- **Project Files:** `/home/user/feature-store-lab/` — `sample_data.json`, `requirements.txt`, `README.md`
- **Environment Info:** `/home/user/lab_env.txt` — includes `S3_BUCKET`, `ROLE_ARN`, `ACCOUNT_ID`, `REGION`

The feature group is **not** created by setup — it is created by the student in Task 2 using the AWS CLI. The role ARN is pre-populated in `lab_env.txt` so students can reference it without hunting for it.

---

## 5. Test Cases (50 pts)

**script_01.sh — 5 pts:** AWS credentials valid
- Pass: `sts:GetCallerIdentity` returns an account ID

**script_02.sh — 5 pts:** Feature group `iris-features` exists
- Pass: `sagemaker:DescribeFeatureGroup` returns a result without error
- Saves describe output to `/var/tmp/feature_group.json` for downstream scripts

**script_03.sh — 5 pts:** Feature group status is `Created`
- Pass: `FeatureGroupStatus == "Created"`

**script_04.sh — 5 pts:** Online store is enabled
- Pass: `OnlineStoreConfig.EnableOnlineStore == true`

**script_05.sh — 5 pts:** Correct record identifier and event time field names
- Pass: `RecordIdentifierFeatureName == "record_id"` AND `EventTimeFeatureName == "event_time"`

**script_06.sh — 5 pts:** Offline store S3 URI uses the correct pre-provisioned bucket
- Pass: configured bucket matches `feature-store-lab-<ACCOUNT_ID>`

**script_07.sh — 5 pts:** `ingest_features.py` exists and is syntactically valid Python
- Pass: file present at `/home/user/feature-store-lab/ingest_features.py` and `python3 -m py_compile` passes

**script_08.sh — 5 pts:** Script uses boto3 with the correct client and both API calls
- Pass: script contains `import boto3`, `sagemaker-featurestore-runtime`, `put_record`, `get_record`

**script_09.sh — 5 pts:** `retrieved_records.json` exists, valid JSON, correct fields, count >= 20
- Pass: JSON array present, first record has all required fields, length >= 20

**script_10.sh — 5 pts:** Offline store S3 path has data (script actually ran against AWS)
- Pass: at least 1 file found under `s3://feature-store-lab-<ACCOUNT_ID>/feature-store/<ACCOUNT_ID>/sagemaker/us-west-2/offline-store/iris-features/data/`
- Note: offline sync takes up to 15 minutes after `put_record` calls complete. Instruct students to wait 15 minutes after running their script before submitting. If tests 01–09 pass but test 10 fails, the script ran correctly — ask the student to resubmit after waiting.

---

## 6. Session Token Note

If the platform provides temporary STS credentials, `/home/user/aws_iam_creds.json` includes a `SessionToken` field. Test scripts handle this automatically. The problem statement instructs students to export all three values including `AWS_SESSION_TOKEN` before running their script — this is required for boto3 to authenticate correctly.

---

## 7. Troubleshooting

**Test 02 fails: feature group not found**
- Student hasn't run the `create-feature-group` command yet, or used the wrong name. Name must be exactly `iris-features` (hyphen, all lowercase).

**Test 03 fails: status is `Creating`**
- Feature group is still provisioning. Wait 30–60 seconds and resubmit.

**Test 04 fails: online store not enabled**
- Student omitted `--online-store-config` or set `EnableOnlineStore` to false. Feature groups cannot be modified after creation — the student must delete and recreate it: `aws sagemaker delete-feature-group --feature-group-name iris-features --region us-west-2`

**Test 05 fails: wrong identifier or event time**
- Student used different field names. Feature groups cannot be modified — delete and recreate with `--record-identifier-feature-name record_id` and `--event-time-feature-name event_time`.

**Test 06 fails: wrong bucket**
- Student typed a different bucket name in `--offline-store-config` instead of reading it from `lab_env.txt`. Delete and recreate with the correct bucket.

**Test 07 fails: file not found**
- Script saved to wrong path. Must be exactly `/home/user/feature-store-lab/ingest_features.py`.

**Test 08 fails: missing put_record or get_record**
- Student implemented only ingestion or only retrieval. Both are required.

**Test 09 fails: missing fields**
- Student saved the raw Feature Store response format (`{"FeatureName":..., "ValueAsString":...}`) directly. Must convert to a plain dict: `{f["FeatureName"]: f["ValueAsString"] for f in response["Record"]}`.

**Test 10 fails: S3 path empty**
- Either the script did not actually call `put_record` against AWS (credentials not exported), or offline sync hasn't completed. Check whether test_09 passed — if yes, just wait and resubmit.
