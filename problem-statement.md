# Feature Store: Ingest and Retrieve — Lab Question

---

## Description

In this lab, you will work with **Amazon SageMaker Feature Store** — the managed feature repository that enables teams to store, share, and reuse ML features across training and inference pipelines.

You will:

1. Create a **Feature Group** using the AWS CLI with both an online store (for low-latency real-time retrieval) and an offline store (for batch training access via S3)
2. Write a **Python script** using `boto3` to ingest 20 Iris dataset records into the feature group
3. Retrieve all 20 records from the **online store** and save them to a JSON file

This simulates a real-world MLOps workflow where a data engineering team publishes features to a central store, and ML engineers consume them for both model training (offline) and real-time inference (online).

---

## Prerequisites

The following resources are pre-provisioned in `us-west-2`:

- **S3 bucket** for the offline store (name in `/home/user/lab_env.txt`)
- **AWS credentials** at `/home/user/aws_iam_creds.json`

Pre-created files on your machine:

- `/home/user/lab_env.txt` — environment details (bucket name, region, account ID)
- `/home/user/aws_iam_creds.json` — AWS credentials
- `/home/user/feature-store-lab/sample_data.json` — 20 Iris records to ingest
- `/home/user/feature-store-lab/requirements.txt` — Python dependencies

---

## Tasks

### 1. Review Your Environment

```bash
cat /home/user/lab_env.txt
cat /home/user/feature-store-lab/sample_data.json
```

Note the `S3_BUCKET` value from `lab_env.txt` — you will need it when creating the feature group.

---

### 2. Create the Feature Group

Use the AWS CLI to create a feature group named `iris-features` with the following specification:

- **Feature group name:** `iris-features`
- **Record identifier feature name:** `record_id`
- **Event time feature name:** `event_time`
- **Online store:** enabled
- **Offline store S3 URI:** `s3://<S3_BUCKET>/feature-store/` (use `S3_BUCKET` from `lab_env.txt`)
- **Role ARN:** use `ROLE_ARN` from `lab_env.txt` — required for offline store access
- **Feature definitions** — 7 features with these exact names and types:
  - `record_id` — String
  - `sepal_length` — Fractional
  - `sepal_width` — Fractional
  - `petal_length` — Fractional
  - `petal_width` — Fractional
  - `species` — String
  - `event_time` — String

Use the AWS CLI `sagemaker create-feature-group` command to create it. Refer to the AWS CLI reference documentation if needed:
https://docs.aws.amazon.com/cli/latest/reference/sagemaker/create-feature-group.html

Once created, verify the feature group reaches `Created` status before proceeding:

```bash
aws sagemaker describe-feature-group \
  --feature-group-name iris-features \
  --region us-west-2 \
  --query 'FeatureGroupStatus' \
  --output text
```

Run this every 15–20 seconds until you see `Created`. Do not proceed until the status is `Created`.

---

### 3. Install Dependencies

```bash
cd /home/user/feature-store-lab
python3 -m pip install -r requirements.txt
```

`boto3` is the AWS SDK for Python — it lets you interact with any AWS service programmatically, the same way the AWS CLI does but from Python code. You will use it to ingest and retrieve records in the next step.

---

### 4. Set AWS Credentials for boto3

boto3 reads credentials from environment variables. Export them before running your script:

```bash
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=us-west-2
```

---

### 5. Write the Ingestion and Retrieval Script

Create the file `/home/user/feature-store-lab/ingest_features.py`.

Your script must:

**Load** all 20 records from `sample_data.json`.

**Ingest** each record into `iris-features` using the `sagemaker-featurestore-runtime` boto3 client and `put_record()`. Create the client like this:

```python
import boto3

fs_runtime = boto3.client(
    "sagemaker-featurestore-runtime",
    region_name="us-west-2",
)
```

Each `put_record()` call requires a `Record` parameter — a list of dicts, each with `FeatureName` and `ValueAsString`. Note that **all values must be strings**, even numeric ones. Example for one record:

```python
fs_runtime.put_record(
    FeatureGroupName="iris-features",
    Record=[
        {"FeatureName": "record_id",    "ValueAsString": "1"},
        {"FeatureName": "sepal_length", "ValueAsString": "5.1"},
        {"FeatureName": "sepal_width",  "ValueAsString": "3.5"},
        {"FeatureName": "petal_length", "ValueAsString": "1.4"},
        {"FeatureName": "petal_width",  "ValueAsString": "0.2"},
        {"FeatureName": "species",      "ValueAsString": "setosa"},
        {"FeatureName": "event_time",   "ValueAsString": "2024-01-01T00:00:00Z"},
    ]
)
```

**Retrieve** all 20 records from the online store using `get_record()`. Retrieve each record by its `record_id`. The response comes back in Feature Store format — convert it to a plain Python dict before saving:

```python
response = fs_runtime.get_record(
    FeatureGroupName="iris-features",
    RecordIdentifierValueAsString="1",
)
# response["Record"] is a list of {"FeatureName": ..., "ValueAsString": ...}
# Convert to a plain dict:
row = {f["FeatureName"]: f["ValueAsString"] for f in response["Record"]}
```

**Save** the list of retrieved dicts to `retrieved_records.json` as a JSON array.

> **Tip:** Add `time.sleep(5)` after all `put_record` calls and before starting retrieval as a small safety margin.

---

### 6. Run the Script

```bash
cd /home/user/feature-store-lab
python ingest_features.py
```

Expected output:

```
Loaded 20 records from sample_data.json
Ingesting 20 records into 'iris-features'...
  Ingested record 1/20: record_id=1
  ...
Retrieving 20 records from online store...
  Retrieved record_id=1, species=setosa
  ...
Saved 20 records to retrieved_records.json
```

---

### 7. Verify the Output

```bash
# Check the file was created
ls -la /home/user/feature-store-lab/retrieved_records.json

# Confirm record count
python3 -c "import json; d=json.load(open('retrieved_records.json')); print(f'Records: {len(d)}')"

# Preview the first 2 records
python3 -c "import json; d=json.load(open('retrieved_records.json')); [print(r) for r in d[:2]]"
```

---

### 8. Check Offline Store Before Submitting

The offline store syncs to S3 asynchronously — this takes up to 15 minutes after your script runs. Run this command to check when the data has landed:

```bash
ACCOUNT_ID=$(grep ACCOUNT_ID /home/user/lab_env.txt | cut -d= -f2)
BUCKET=$(grep S3_BUCKET /home/user/lab_env.txt | cut -d= -f2)

aws s3 ls s3://${BUCKET}/feature-store/ \
  --recursive \
  --region us-west-2 \
  --no-cli-pager | grep "iris-features" | grep ".parquet"
```

If the command returns file paths, the offline store is ready and you can submit. If it returns nothing, wait a few more minutes and run it again.

---

## Expected Outcomes

When complete you will have:

- A SageMaker Feature Group named `iris-features` with status `Created`, online store enabled, and offline store pointing to the pre-provisioned S3 bucket
- `/home/user/feature-store-lab/ingest_features.py` — your ingestion and retrieval script
- `/home/user/feature-store-lab/retrieved_records.json` — 20 retrieved Iris records as a JSON array

Each record in `retrieved_records.json` should look like:

```json
{
  "record_id": "1",
  "sepal_length": "5.1",
  "sepal_width": "3.5",
  "petal_length": "1.4",
  "petal_width": "0.2",
  "species": "setosa",
  "event_time": "2024-01-01T00:00:00Z"
}
```

---

## Skills Practiced

- Creating a SageMaker Feature Store feature group via the AWS CLI
- Understanding online store vs offline store and when each is used
- Using boto3 to interact with AWS services from Python
- Ingesting records with `put_record` and retrieving them with `get_record`
- Working with the Feature Store record format (`FeatureName` / `ValueAsString`)
