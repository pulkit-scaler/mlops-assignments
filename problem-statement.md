# MLflow + DVC Experiment Tracking Lab

---

## Description

You are a data scientist at a wine producer. The quality control team wants a reproducible, versioned ML workflow: the dataset must be tracked with **DVC** so it can be pulled in any environment, and every training run must be tracked with **MLflow** so results can be compared systematically. Finally, the whole pipeline must run automatically in **GitHub Actions** on every push.

A project scaffold is pre-created at `/home/user/wine-mlflow/`. It contains two scripts with `# TODO` comments — read the comments to understand what each section must do.

---

## What Is Already Set Up

- Python 3 with `mlflow`, `scikit-learn`, `dvc`, `pandas`, `matplotlib`, `seaborn`, and `numpy` installed
- An S3 bucket for your DVC remote (name is in `/home/user/lab_env.txt`)
- AWS credentials in `/home/user/aws_iam_creds.json`
- Project scaffold at `/home/user/wine-mlflow/` containing:
  - `data/wine.csv` — the dataset (178 samples, 13 features, 3 wine classes)
  - `train.py` — training script with `# TODO` placeholders
  - `query_runs.py` — query script with `# TODO` placeholders
  - `run_experiments.sh` — runs all required experiments in one command (do not modify)
  - `requirements.txt` — pinned dependencies for CI (do not modify)
  - `.github/workflows/train-pipeline.yml` — workflow scaffold with `# TODO` placeholders

---

## Tasks

### 1. Prepare GitHub Credentials

Create the file below exactly as specified:

`/home/user/github_creds.json`

```json
{
  "repository_name": "<your_repo_name>",
  "access_token": "<your_github_personal_access_token>",
  "username": "<your_github_username>"
}
```

---

### 2. Push the Scaffold to GitHub

Create a new repository on GitHub, then push the project scaffold:

```bash
cd /home/user/wine-mlflow
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your_username>/<your_repo_name>.git
git push -u origin main
```

**Note:** The workflow scaffold contains `# TODO` placeholders which make it invalid YAML. GitHub may reject the push. If so, complete the workflow (Task 8) before pushing, or temporarily remove the `.github/` folder from your first commit and add it later.

---

### 3. Set Up DVC and Version the Dataset

Inside `/home/user/wine-mlflow/`, initialise DVC, configure the S3 bucket as your remote, track the dataset, and push it to S3.

The S3 bucket name is in `/home/user/lab_env.txt` under `S3_BUCKET`.

Export your AWS credentials before running DVC commands:

```bash
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKeyId' /home/user/aws_iam_creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.SecretAccessKey' /home/user/aws_iam_creds.json)
export AWS_DEFAULT_REGION=$(grep REGION /home/user/lab_env.txt | cut -d= -f2)
```

After completing this step, commit the DVC pointer file and configuration to git and push to GitHub:

```bash
git add data/wine.csv.dvc .dvc/ .gitignore
git commit -m "Track dataset with DVC"
git push origin main
```

---

### 4. Add GitHub Repository Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add:

```
AWS_ACCESS_KEY_ID       →  From /home/user/aws_iam_creds.json
AWS_SECRET_ACCESS_KEY   →  From /home/user/aws_iam_creds.json
AWS_REGION              →  From /home/user/lab_env.txt (us-west-2)
```

---

### 5. Complete `train.py`

Open `/home/user/wine-mlflow/train.py` and implement each `# TODO` inside `run_experiment(args)`. Delete the stub block at the bottom of the function once you have implemented the TODOs.

Verify it works locally before pushing:

```bash
cd /home/user/wine-mlflow
python3 train.py --model random-forest --max-depth 5
```

A successful run writes to `mlruns/` and prints the run name with its accuracy.

---

### 6. Run All Experiments

Once `train.py` is working, run all required experiments:

```bash
cd /home/user/wine-mlflow
bash run_experiments.sh
```

---

### 7. Complete `query_runs.py`

Open `/home/user/wine-mlflow/query_runs.py` and implement each `# TODO`.

Verify it works:

```bash
cd /home/user/wine-mlflow
python3 query_runs.py
```

It should print the top 5 runs ranked by accuracy.

---

### 8. Complete the GitHub Actions Workflow

Open `/home/user/wine-mlflow/.github/workflows/train-pipeline.yml` and implement the workflow. The `# TODO` comments inside the file describe what each job must do.

---

### 9. Push and Verify

Commit all changes and push:

```bash
cd /home/user/wine-mlflow
git add .
git commit -m "Complete MLflow + DVC lab"
git push origin main
```

Go to your repository → **Actions** tab. Both jobs in the `MLflow Training Pipeline` workflow must complete with a green checkmark ✅.

---

## Requirements

### DVC

- `dvc init` must be run inside the project
- The DVC remote must point to the S3 bucket from `lab_env.txt`
- `data/wine.csv` must be tracked with DVC (`wine.csv.dvc` committed to git)
- The data must be pushed to S3 (`dvc push`)

### `train.py`

Must use MLflow to:

- Set a tracking URI and experiment name
- Start a named run
- Log model hyperparameters as parameters
- Log `accuracy`, `f1_score`, `precision`, and `recall` as metrics
- Log a confusion-matrix plot as an artifact
- Log the trained model with a signature
- Set at least one tag

### `query_runs.py`

Must use `MlflowClient` to retrieve the `wine-quality-classification` experiment, search all runs sorted by accuracy, and print the top 5.

### Workflow

- Name: **`MLflow Training Pipeline`**
- Triggers: push to `main` and `workflow_dispatch`
- Two jobs: `train` → `report`
- The `train` job must pull data via DVC before running experiments
- Both jobs must complete successfully and produce the `mlruns-artifact`

---

## Outcomes

When complete, GitHub Actions will show:

```
train  →  report
```

The `train` job pulls the versioned dataset from S3, runs all experiments, and passes results to the `report` job, which prints the leaderboard.
