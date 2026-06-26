# MLflow + DVC Experiment Tracking Lab — Complete Solution

## Task 1: GitHub Credentials

```bash
cat > /home/user/github_creds.json << 'EOF'
{
  "repository_name": "wine-mlflow-lab",
  "access_token": "<YOUR_GITHUB_PAT>",
  "username": "<YOUR_GITHUB_USERNAME>"
}
EOF
```

---

## Task 2: Push Scaffold to GitHub

```bash
cd /home/user/wine-mlflow
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<username>/wine-mlflow-lab.git
git push -u origin main
```

Note: `git config` (user.email, user.name, defaultBranch) is pre-configured by the setup script.

---

## Task 3: DVC Setup and Dataset Versioning

```bash
cd /home/user/wine-mlflow

# Export AWS credentials for DVC to reach S3
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=$(grep REGION /home/user/lab_env.txt | cut -d= -f2)

# Get the bucket name
S3_BUCKET=$(grep S3_BUCKET /home/user/lab_env.txt | cut -d= -f2)

# Initialise DVC
dvc init

# Add the S3 bucket as the default remote
dvc remote add -d s3remote s3://${S3_BUCKET}/

# Track the dataset with DVC
dvc add data/wine.csv

# Push the dataset to S3
dvc push

# Commit DVC files to git
git add data/wine.csv.dvc .dvc/ .gitignore
git commit -m "Track dataset with DVC"
git push origin main
```

---

## Task 4: GitHub Repository Secrets

Go to Settings → Secrets and variables → Actions and add:

```
AWS_ACCESS_KEY_ID       →  AccessKeyId from /home/user/aws_iam_creds.json
AWS_SECRET_ACCESS_KEY   →  SecretAccessKey from /home/user/aws_iam_creds.json
AWS_REGION              →  us-west-2
```

---

## Task 5: Complete train.py

Replace the `run_experiment()` function. Delete the stub block at the bottom (the lines from `t0 = time.time()` through `print("  WARNING: MLflow tracking not yet implemented")`).

```python
def run_experiment(args):
    X_train, X_test, y_train, y_test, feature_names = load_data()
    model, params = build_model(args)

    # TODO 1
    mlflow.set_tracking_uri("file:./mlruns")

    # TODO 2
    mlflow.set_experiment("wine-quality-classification")

    if args.model == "random-forest":
        run_name = f"rf-depth{args.max_depth}-trees{args.n_estimators}"
    elif args.model == "logistic-regression":
        run_name = f"lr-C{args.C}"
    else:
        run_name = f"svm-{args.kernel}"

    # TODO 3
    with mlflow.start_run(run_name=run_name):

        # TODO 4
        mlflow.log_params(params)
        mlflow.log_param("model_type", model.__class__.__name__)
        mlflow.log_param("data_scaling", "StandardScaler")

        # TODO 5
        t0 = time.time()
        model.fit(X_train, y_train)
        training_time = time.time() - t0
        y_pred = model.predict(X_test)
        accuracy  = accuracy_score(y_test, y_pred)
        f1        = f1_score(y_test, y_pred, average="weighted")
        precision = precision_score(y_test, y_pred, average="weighted", zero_division=0)
        recall    = recall_score(y_test, y_pred, average="weighted", zero_division=0)

        # TODO 6
        mlflow.log_metrics({
            "accuracy": accuracy,
            "f1_score": f1,
            "precision": precision,
            "recall": recall,
            "training_time_secs": training_time,
        })

        # TODO 7
        with tempfile.TemporaryDirectory() as tmpdir:
            cm_path = os.path.join(tmpdir, "confusion_matrix.png")
            save_confusion_matrix(y_test, y_pred, cm_path)
            mlflow.log_artifacts(tmpdir, artifact_path="plots")

        # TODO 8
        signature = infer_signature(X_train, model.predict(X_train))
        mlflow.sklearn.log_model(model, "model", signature=signature, input_example=X_train[:3])

        # TODO 9
        mlflow.set_tag("model_family", args.model)

        print(f"[{run_name}] accuracy={accuracy:.4f}  f1={f1:.4f}  time={training_time:.2f}s")
```

Verify locally:

```bash
python3 train.py --model random-forest --max-depth 5
```

---

## Task 6: Run All Experiments

```bash
bash run_experiments.sh
```

---

## Task 7: Complete query_runs.py

Replace the entire file content:

```python
import mlflow
from mlflow.tracking import MlflowClient

mlflow.set_tracking_uri("file:./mlruns")

client = MlflowClient()

experiment = client.get_experiment_by_name("wine-quality-classification")

if experiment is None:
    print("Experiment not found. Did you run train.py at least once?")
else:
    runs = client.search_runs(
        experiment_ids=[experiment.experiment_id],
        order_by=["metrics.accuracy DESC"],
    )

    print("\nTop 5 runs by accuracy:\n")
    for i, run in enumerate(runs[:5], 1):
        name = run.data.tags.get("mlflow.runName", "unnamed")
        acc  = run.data.metrics.get("accuracy", 0.0)
        f1   = run.data.metrics.get("f1_score", 0.0)
        print(f"{i}. {name}")
        print(f"   Accuracy : {acc:.4f}")
        print(f"   F1 Score : {f1:.4f}")
        print(f"   Params   : {run.data.params}")
        print()
```

---

## Task 8: Complete the GitHub Actions Workflow

Replace `.github/workflows/train-pipeline.yml`:

```yaml
name: MLflow Training Pipeline

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: python3 -m pip install -r requirements.txt

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Pull data from DVC remote
        run: dvc pull data/wine.csv

      - name: Run all experiments
        run: bash run_experiments.sh

      - name: Upload mlruns artifact
        uses: actions/upload-artifact@v4
        with:
          name: mlruns-artifact
          path: mlruns/

  report:
    runs-on: ubuntu-latest
    needs: train
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: python3 -m pip install -r requirements.txt

      - name: Download mlruns artifact
        uses: actions/download-artifact@v4
        with:
          name: mlruns-artifact
          path: mlruns

      - name: Print experiment leaderboard
        run: python3 query_runs.py
```

---

## Task 9: Push and Verify

```bash
cd /home/user/wine-mlflow
git add .
git commit -m "Complete MLflow + DVC lab"
git push origin main
```

Go to repository → Actions tab → verify both train and report jobs pass.
