"""
Reference Solution — register_model.py
========================================
Registers a boto3 model version in the SageMaker Model Registry
and saves registration details including the Canvas model.

Usage:
    # Set credentials first:
    export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
    export AWS_DEFAULT_REGION=us-west-2
    # If session token is present:
    # export AWS_SESSION_TOKEN=$(jq -r '.SessionToken' /home/user/aws_iam_creds.json)

    python3 register_model.py
"""
import boto3
import json

REGION = "us-west-2"
GROUP_NAME = "iris-model-group"

# Read values from lab_env.txt
env_vars = {}
with open("/home/user/lab_env.txt", "r") as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            env_vars[key] = value

MODEL_ARTIFACT_URI = env_vars["MODEL_ARTIFACT_URI"]
SKLEARN_IMAGE = env_vars["SKLEARN_IMAGE"]


def find_canvas_model(sm_client, group_name):
    """Find the Canvas-originated model package in the group."""
    response = sm_client.list_model_packages(ModelPackageGroupName=group_name)
    for pkg in response.get("ModelPackageSummaryList", []):
        arn = pkg["ModelPackageArn"]
        detail = sm_client.describe_model_package(ModelPackageName=arn)
        containers = detail.get("InferenceSpecification", {}).get("Containers", [])
        if containers:
            image = containers[0].get("Image", "")
            # Canvas uses AutoML containers, not sagemaker-scikit-learn
            if "sagemaker-scikit-learn" not in image:
                return arn
    return None


if __name__ == "__main__":
    sm = boto3.client("sagemaker", region_name=REGION)

    # --- Find the Canvas model (already shared via UI) ---
    print("Looking for Canvas model in the registry...")
    canvas_arn = find_canvas_model(sm, GROUP_NAME)
    if canvas_arn:
        print(f"  Canvas model found: {canvas_arn}")
    else:
        print("  WARNING: No Canvas model found. Share your Canvas model first.")
        print("  Continuing with boto3 registration anyway...")

    # --- Register boto3 version (PendingManualApproval) ---
    print("\nRegistering boto3 model version (PendingManualApproval)...")
    response = sm.create_model_package(
        ModelPackageGroupName=GROUP_NAME,
        ModelPackageDescription="Iris classifier - scikit-learn Random Forest baseline",
        InferenceSpecification={
            "Containers": [
                {
                    "Image": SKLEARN_IMAGE,
                    "ModelDataUrl": MODEL_ARTIFACT_URI,
                }
            ],
            "SupportedContentTypes": ["text/csv", "application/json"],
            "SupportedResponseMIMETypes": ["application/json"],
            "SupportedRealtimeInferenceInstanceTypes": [
                "ml.t2.medium",
                "ml.m5.large",
            ],
            "SupportedTransformInstanceTypes": ["ml.m5.large"],
        },
        ModelApprovalStatus="PendingManualApproval",
    )
    boto3_arn = response["ModelPackageArn"]
    print(f"  boto3 model ARN: {boto3_arn}")

    # --- Approve the boto3 version ---
    print("\nApproving boto3 model version...")
    sm.update_model_package(
        ModelPackageArn=boto3_arn, ModelApprovalStatus="Approved"
    )
    print("  boto3 model approved.")

    # --- Save registration details ---
    details = {
        "model_package_group_name": GROUP_NAME,
        "canvas_model_package_arn": canvas_arn or "NOT_FOUND",
        "boto3_model_package_arn": boto3_arn,
        "boto3_approval_status": "Approved",
        "inference_image": SKLEARN_IMAGE,
        "model_data_url": MODEL_ARTIFACT_URI,
        "total_versions": 2,
    }

    output_path = "/home/user/model-registry-lab/registration_details.json"
    with open(output_path, "w") as f:
        json.dump(details, f, indent=2)

    print(f"\nRegistration details saved to {output_path}")
    print(json.dumps(details, indent=2))
