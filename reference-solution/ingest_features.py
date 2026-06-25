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
                {"FeatureName": "record_id",    "ValueAsString": str(record["record_id"])},
                {"FeatureName": "sepal_length",  "ValueAsString": str(record["sepal_length"])},
                {"FeatureName": "sepal_width",   "ValueAsString": str(record["sepal_width"])},
                {"FeatureName": "petal_length",  "ValueAsString": str(record["petal_length"])},
                {"FeatureName": "petal_width",   "ValueAsString": str(record["petal_width"])},
                {"FeatureName": "species",       "ValueAsString": str(record["species"])},
                {"FeatureName": "event_time",    "ValueAsString": str(record["event_time"])},
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
