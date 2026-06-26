#!/bin/bash

set -euo pipefail

LOG="/home/user/setup_log.txt"
touch "$LOG"
chown user:user "$LOG"

log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"
}

fail() {
    log "FAILED at: $*"
    chown -R user:user /home/user/ 2>/dev/null || true
    exit 1
}

trap 'fail "line $LINENO"' ERR

BASE_DIR="/home/user/wine-mlflow"
REGION="${AWS_REGION:-us-west-2}"

log "================================================"
log "MLflow + DVC Experiment Tracking Lab - Setup"
log "================================================"

# ==========================================
# 0. Get account ID
# ==========================================
log "[0/4] Getting account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log "  Region: ${REGION} | Account: ${ACCOUNT_ID}"

# ==========================================
# 1. Install Python and all dependencies
# ==========================================
log "[1/4] Installing Python and dependencies..."

apt-get update -y -qq >> "$LOG" 2>&1
log "  apt-get update done"

apt-get install -y -qq python3 python3-pip git curl jq >> "$LOG" 2>&1
log "  apt-get install done"

# Upgrade pip (system pip 20.0.2 is too old for dependency resolution)
python3 -m pip install --upgrade pip >> "$LOG" 2>&1
log "  pip upgraded"

# Python 3.8-compatible versions (all have manylinux wheels — no compilation)
python3 -m pip install --quiet \
    mlflow==2.14.3 \
    scikit-learn==1.3.2 \
    pandas==2.0.3 \
    matplotlib==3.7.5 \
    seaborn==0.13.2 \
    numpy==1.24.4 \
    "dvc[s3]==2.58.2" \
    boto3==1.34.144 >> "$LOG" 2>&1
log "  pip install done"

# Set git defaults so 'git commit' works without extra config
git config --global user.email "student@lab.local"
git config --global user.name "Student"
git config --global init.defaultBranch main
log "  git configured"

log "  Python $(python3 --version 2>&1)"
log "  MLflow $(python3 -c 'import mlflow; print(mlflow.__version__)')"
log "  DVC $(python3 -c 'import dvc; print(dvc.__version__)')"

# ==========================================
# 2. Create S3 bucket for DVC remote
# ==========================================
log "[2/4] Creating S3 bucket for DVC remote..."

S3_BUCKET="wine-mlflow-dvc-${ACCOUNT_ID}"

aws s3api create-bucket \
    --bucket "${S3_BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}" 2>/dev/null || true

log "  S3 bucket: s3://${S3_BUCKET}"

# ==========================================
# 3. Save AWS credentials
# ==========================================
log "[3/4] Saving AWS credentials..."

if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    CRED_KEY="$AWS_ACCESS_KEY_ID"
    CRED_SECRET="$AWS_SECRET_ACCESS_KEY"
else
    CRED_KEY=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
    CRED_SECRET=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
fi

if [ -z "$CRED_KEY" ] || [ -z "$CRED_SECRET" ]; then
    log "  ERROR: Could not extract AWS credentials"
    exit 1
fi

cat > /home/user/aws_iam_creds.json << CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}"
}
CREDS
chmod 600 /home/user/aws_iam_creds.json
log "  Credentials saved"

# ==========================================
# 4. Create project scaffold
# ==========================================
log "[4/4] Creating project scaffold..."

mkdir -p ${BASE_DIR}/data

# --- Write the Wine Quality CSV to disk ---
python3 - << PYEOF
import pandas as pd
from sklearn.datasets import load_wine

wine = load_wine()
df = pd.DataFrame(wine.data, columns=wine.feature_names)
df["target"] = wine.target
df.to_csv("${BASE_DIR}/data/wine.csv", index=False)
print(f"  Wrote {len(df)} rows to data/wine.csv")
PYEOF
log "  Dataset written"

# --- train.py ---
cat > ${BASE_DIR}/train.py << 'PYEOF'
"""
Wine Quality Classification - MLflow Experiment Tracking
=========================================================
Complete each TODO to instrument this script with MLflow tracking.

The dataset is loaded from data/wine.csv (managed by DVC).

Run with:
    python3 train.py --model random-forest --max-depth 5
    python3 train.py --model logistic-regression --C 1.0
    python3 train.py --model svm --kernel rbf
"""

import argparse
import os
import tempfile
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd

# MLflow imports
import mlflow
import mlflow.sklearn
from mlflow.models import infer_signature

# Sklearn imports
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.svm import SVC
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    confusion_matrix,
)

DATA_PATH = "data/wine.csv"


# ──────────────────────────────────────────────────────────────
# Data loading — reads from data/wine.csv (do not modify)
# ──────────────────────────────────────────────────────────────
def load_data():
    df = pd.read_csv(DATA_PATH)
    X = df.drop("target", axis=1).values
    y = df["target"].values
    feature_names = df.drop("target", axis=1).columns.tolist()
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)
    return X_train_s, X_test_s, y_train, y_test, feature_names


# ──────────────────────────────────────────────────────────────
# Model factory (do not modify)
# ──────────────────────────────────────────────────────────────
def build_model(args):
    if args.model == "random-forest":
        params = {
            "n_estimators": args.n_estimators,
            "max_depth": args.max_depth,
            "random_state": 42,
        }
        model = RandomForestClassifier(**params)
    elif args.model == "logistic-regression":
        params = {
            "C": args.C,
            "penalty": "l2",
            "solver": "lbfgs",
            "max_iter": 1000,
            "random_state": 42,
        }
        model = LogisticRegression(**params)
    elif args.model == "svm":
        params = {
            "kernel": args.kernel,
            "C": args.C,
            "gamma": "scale",
            "random_state": 42,
        }
        model = SVC(**params)
    else:
        raise ValueError(f"Unknown model: {args.model}")
    return model, params


# ──────────────────────────────────────────────────────────────
# Artifact helper (do not modify)
# ──────────────────────────────────────────────────────────────
def save_confusion_matrix(y_test, y_pred, path):
    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(7, 5))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues")
    plt.title("Confusion Matrix")
    plt.ylabel("True Label")
    plt.xlabel("Predicted Label")
    plt.tight_layout()
    plt.savefig(path)
    plt.close()


# ──────────────────────────────────────────────────────────────
# Main training + tracking function  ← complete the TODOs below
# ──────────────────────────────────────────────────────────────
def run_experiment(args):
    X_train, X_test, y_train, y_test, feature_names = load_data()
    model, params = build_model(args)

    # TODO 1: Set the MLflow tracking URI to "file:./mlruns"

    # TODO 2: Set the experiment name to "wine-quality-classification"

    # Build a descriptive run name (do not modify)
    if args.model == "random-forest":
        run_name = f"rf-depth{args.max_depth}-trees{args.n_estimators}"
    elif args.model == "logistic-regression":
        run_name = f"lr-C{args.C}"
    else:
        run_name = f"svm-{args.kernel}"

    # TODO 3: Start an MLflow run (use run_name) and place TODOs 4-9 inside it

        # TODO 4: Log all entries in `params` with mlflow.log_params()
        #         Also log "model_type" and "data_scaling"="StandardScaler"

        # TODO 5: Train the model and compute accuracy, f1_score, precision, recall

        # TODO 6: Log all four metrics with mlflow.log_metrics()

        # TODO 7: Log a confusion-matrix PNG as an artifact using a
        #         temporary directory and save_confusion_matrix()

        # TODO 8: Infer a model signature and log the model with
        #         mlflow.sklearn.log_model()

        # TODO 9: Set at least one tag with mlflow.set_tag()

    # ── Remove this stub once you have implemented the TODOs above ──
    t0 = time.time()
    model.fit(X_train, y_train)
    training_time = time.time() - t0
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"[{run_name}] accuracy={accuracy:.4f}  time={training_time:.2f}s")
    print("  WARNING: MLflow tracking not yet implemented")


# ──────────────────────────────────────────────────────────────
# CLI (do not modify)
# ──────────────────────────────────────────────────────────────
def parse_args():
    p = argparse.ArgumentParser(description="Wine Quality classifier with MLflow")
    p.add_argument("--model", required=True,
                   choices=["random-forest", "logistic-regression", "svm"])
    p.add_argument("--n-estimators", type=int, default=100)
    p.add_argument("--max-depth", type=int, default=None)
    p.add_argument("--C", type=float, default=1.0)
    p.add_argument("--kernel", choices=["linear", "rbf", "poly"], default="rbf")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_experiment(args)
PYEOF
log "  train.py written"

# --- query_runs.py ---
cat > ${BASE_DIR}/query_runs.py << 'PYEOF'
"""
Query MLflow Runs
=================
Complete the TODOs to query the wine-quality-classification experiment
and print the top 5 runs sorted by accuracy.

Run after training at least 5 models:
    python3 query_runs.py
"""

import mlflow
from mlflow.tracking import MlflowClient

# TODO 1: Set the tracking URI so the client knows where to look

# TODO 2: Create an MlflowClient instance

# TODO 3: Get the experiment by name "wine-quality-classification"

# TODO 4: Search for all runs sorted by accuracy descending

# TODO 5: Print the top 5 runs — show rank, run name, accuracy, F1, and params

print("query_runs.py: complete the TODOs above.")
PYEOF
log "  query_runs.py written"

# --- run_experiments.sh ---
cat > ${BASE_DIR}/run_experiments.sh << 'BASH'
#!/bin/bash
# Run all required experiments in one go.
# Execute AFTER completing the TODOs in train.py.
set -e
cd "$(dirname "$0")"

echo "Running Random Forest experiments..."
python3 train.py --model random-forest --max-depth 5
python3 train.py --model random-forest --max-depth 10
python3 train.py --model random-forest --max-depth 20

echo "Running Logistic Regression experiments..."
python3 train.py --model logistic-regression --C 0.1
python3 train.py --model logistic-regression --C 1.0

echo "Running SVM experiments..."
python3 train.py --model svm --kernel rbf
python3 train.py --model svm --kernel linear

echo ""
echo "All experiments complete."
echo "Run: python3 query_runs.py"
BASH
chmod +x ${BASE_DIR}/run_experiments.sh
log "  run_experiments.sh written"

# --- requirements.txt ---
cat > ${BASE_DIR}/requirements.txt << 'EOF'
mlflow==2.14.3
scikit-learn==1.5.2
pandas==2.2.2
matplotlib==3.9.2
seaborn==0.13.2
numpy==1.26.4
dvc==3.51.2
dvc-s3==3.2.0
pathspec==0.11.2
boto3==1.34.144
EOF
log "  requirements.txt written"

# --- .gitignore ---
cat > ${BASE_DIR}/.gitignore << 'EOF'
__pycache__/
*.pyc
*.egg-info/
.env
.venv/
# DVC caches locally — only the .dvc pointer files go to git
.dvc/cache/
.dvc/tmp/
# Raw data file is tracked by DVC, not git
data/wine.csv
# MLflow experiment runs — generated fresh in CI
mlruns/
EOF
log "  .gitignore written"

# --- README.md ---
cat > ${BASE_DIR}/README.md << 'EOF'
# Wine Quality Classification — MLflow + DVC Lab

## Quick Start

```bash
# Step 1 — Set up DVC
dvc init
dvc remote add -d s3remote s3://<your-bucket>/dvc-store
dvc add data/wine.csv
dvc push
git add data/wine.csv.dvc .dvc/config .gitignore
git commit -m "Track dataset with DVC"

# Step 2 — Complete train.py and query_runs.py

# Step 3 — Run all experiments
bash run_experiments.sh

# Step 4 — Query results
python3 query_runs.py
```

## GitHub Actions

The workflow at `.github/workflows/train-pipeline.yml` runs:
1. **train** — pulls data via DVC, runs all experiments, uploads mlruns artifact
2. **report** — downloads mlruns artifact, prints leaderboard
EOF
log "  README.md written"

# --- Workflow scaffold ---
mkdir -p ${BASE_DIR}/.github/workflows
cat > ${BASE_DIR}/.github/workflows/train-pipeline.yml << 'YAML'
# Complete this workflow file.
#
# Workflow name must be: "MLflow Training Pipeline"
# Triggers: push to main AND workflow_dispatch
#
# Required GitHub Secrets (add under Settings → Secrets → Actions):
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
#
# Jobs required (in order):  train  →  report
#
# train job (ubuntu-latest):
#   1. Check out repo
#   2. Set up Python 3.11
#   3. Install dependencies:  python3 -m pip install -r requirements.txt
#   4. Configure AWS credentials using aws-actions/configure-aws-credentials@v4
#      (needed so DVC can reach S3)
#   5. Pull data from DVC remote:  dvc pull data/wine.csv
#   6. Run all experiments:  bash run_experiments.sh
#   7. Upload the mlruns/ directory as an artifact named "mlruns-artifact"
#      using actions/upload-artifact@v4
#
# report job (ubuntu-latest, needs: train):
#   1. Check out repo
#   2. Set up Python 3.11
#   3. Install dependencies
#   4. Download "mlruns-artifact" to path mlruns
#      using actions/download-artifact@v4
#   5. Run:  python3 query_runs.py

name: # TODO

on: # TODO

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      # TODO: implement train job steps

  report:
    runs-on: ubuntu-latest
    needs: train
    steps:
      # TODO: implement report job steps
YAML
log "  workflow scaffold written"

chown -R user:user ${BASE_DIR}
log "  chown done"

# ==========================================
# Save environment info
# ==========================================
cat > /home/user/lab_env.txt << ENV
PROJECT_DIR=${BASE_DIR}
S3_BUCKET=${S3_BUCKET}
REGION=${REGION}
ACCOUNT_ID=${ACCOUNT_ID}
ENV

chown user:user /home/user/lab_env.txt /home/user/aws_iam_creds.json

log ""
log "================================================"
log "Setup Complete!"
log "================================================"
log ""
log "  S3 bucket:  s3://${S3_BUCKET}"
log "  AWS creds:  /home/user/aws_iam_creds.json"
log "  Dataset:    ${BASE_DIR}/data/wine.csv"
log "  Scaffold:   ${BASE_DIR}"
log ""
log "  GitHub Secrets to add:"
log "    AWS_ACCESS_KEY_ID     = ${CRED_KEY}"
log "    AWS_SECRET_ACCESS_KEY = (see /home/user/aws_iam_creds.json)"
log "    AWS_REGION            = ${REGION}"
