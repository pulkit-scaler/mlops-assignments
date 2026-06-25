# Lab 2 — Feature Store: Ingest and Retrieve
# Complete Solution

---

## Step 1 — Review Environment

```bash
cat /home/user/lab_env.txt
cat /home/user/feature-store-lab/sample_data.json
```

---

## Step 2 — Create the Feature Group

```bash
BUCKET=$(grep S3_BUCKET /home/user/lab_env.txt | cut -d= -f2)
ROLE=$(grep ROLE_ARN /home/user/lab_env.txt | cut -d= -f2)

aws sagemaker create-feature-group \
  --feature-group-name iris-features \
  --record-identifier-feature-name record_id \
  --event-time-feature-name event_time \
  --feature-definitions '[{"FeatureName":"record_id","FeatureType":"String"},{"FeatureName":"sepal_length","FeatureType":"Fractional"},{"FeatureName":"sepal_width","FeatureType":"Fractional"},{"FeatureName":"petal_length","FeatureType":"Fractional"},{"FeatureName":"petal_width","FeatureType":"Fractional"},{"FeatureName":"species","FeatureType":"String"},{"FeatureName":"event_time","FeatureType":"String"}]' \
  --online-store-config '{"EnableOnlineStore":true}' \
  --offline-store-config "{\"S3StorageConfig\":{\"S3Uri\":\"s3://${BUCKET}/feature-store/\"}}" \
  --role-arn "$ROLE" \
  --region us-west-2 \
  --no-cli-pager
```

Wait for Created status:

```bash
aws sagemaker describe-feature-group \
  --feature-group-name iris-features \
  --region us-west-2 \
  --query 'FeatureGroupStatus' \
  --output text \
  --no-cli-pager
```

---

## Step 3 — Install Dependencies and Export Credentials

```bash
cd /home/user/feature-store-lab
python3 -m pip install -r requirements.txt

export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=us-west-2
```

---

## Step 4 — ingest_features.py

```python
import json
import time
import boto3

REGION = "us-west-2"
FEATURE_GROUP_NAME = "iris-features"
DATA_FILE = "sample_data.json"
OUTPUT_FILE = "retrieved_records.json"

def main():
    # 1. Load sample data
    with open(DATA_FILE, "r") as f:
        records = json.load(f)
    print(f"Loaded {len(records)} records from {DATA_FILE}")

    # 2. Create boto3 client
    fs_runtime = boto3.client(
        "sagemaker-featurestore-runtime",
        region_name=REGION,
    )

    # 3. Ingest records into online store
    print(f"\nIngesting {len(records)} records into '{FEATURE_GROUP_NAME}'...")
    for i, record in enumerate(records, start=1):
        fs_runtime.put_record(
            FeatureGroupName=FEATURE_GROUP_NAME,
            Record=[
                {"FeatureName": "record_id",   "ValueAsString": str(record["record_id"])},
                {"FeatureName": "sepal_length", "ValueAsString": str(record["sepal_length"])},
                {"FeatureName": "sepal_width",  "ValueAsString": str(record["sepal_width"])},
                {"FeatureName": "petal_length", "ValueAsString": str(record["petal_length"])},
                {"FeatureName": "petal_width",  "ValueAsString": str(record["petal_width"])},
                {"FeatureName": "species",      "ValueAsString": str(record["species"])},
                {"FeatureName": "event_time",   "ValueAsString": str(record["event_time"])},
            ]
        )
        print(f"  Ingested record {i}/{len(records)}: record_id={record['record_id']}")

    # 4. Wait before retrieval
    print("\nWaiting 5 seconds before retrieval...")
    time.sleep(5)

    # 5. Retrieve all records from online store
    print(f"\nRetrieving {len(records)} records from online store...")
    retrieved = []
    for record in records:
        response = fs_runtime.get_record(
            FeatureGroupName=FEATURE_GROUP_NAME,
            RecordIdentifierValueAsString=str(record["record_id"]),
        )
        row = {f["FeatureName"]: f["ValueAsString"] for f in response["Record"]}
        retrieved.append(row)
        print(f"  Retrieved record_id={row['record_id']}, species={row['species']}")

    # 6. Save to JSON
    with open(OUTPUT_FILE, "w") as f:
        json.dump(retrieved, f, indent=2)

    print(f"\nSaved {len(retrieved)} records to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
```

---

## Step 5 — Run the Script

```bash
python3 ingest_features.py
```

---

## Step 6 — Verify Output

```bash
python3 -c "import json; d=json.load(open('retrieved_records.json')); print(f'Records: {len(d)}')"
```

---

## Step 7 — Check Offline Store Before Submitting

```bash
BUCKET=$(grep S3_BUCKET /home/user/lab_env.txt | cut -d= -f2)

aws s3 ls s3://${BUCKET}/feature-store/ \
  --recursive \
  --region us-west-2 \
  --no-cli-pager | grep "iris-features" | grep ".parquet"
```

When parquet files appear in the output, submit for grading.
