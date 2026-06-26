# MLflow + DVC Experiment Tracking Lab — Instructor Setup Guide

## 1. Platform Configuration

| Setting            | Value            |
|--------------------|------------------|
| **Container OS**   | **Ubuntu** (required — Alpine is not supported) |
| **Setup file**     | `Setup.zip`      |
| **Test Case Zip**  | `TestCase.zip`   |
| **Max Score**      | 50               |
| **Time Limit**     | 40 minutes       |
| **Duration**       | 90 minutes       |

### AWS Policy to Select

- ✅ **DSML playground policy**

Provides `s3:*` and `sts:*` in us-west-2. No IAM user creation needed.

---

## 2. Container Environment

| Detail          | Value                                         |
|-----------------|-----------------------------------------------|
| **OS**          | Ubuntu 20.04 LTS (Focal Fossa)                |
| **Python**      | 3.8 (installed by setup script via apt-get)    |
| **pip**         | Upgraded to latest at setup time               |
| **Key packages**| mlflow 2.14.3, scikit-learn 1.3.2, dvc 2.58.2 |

The container ships with NO Python pre-installed. The setup script installs Python 3.8 and all dependencies with Python 3.8-compatible versions that have pre-built manylinux wheels (no compilation needed).

**requirements.txt** (used in GitHub Actions with Python 3.11) has newer versions:
scikit-learn 1.5.2, pandas 2.2.2, numpy 1.26.4, dvc 3.51.2, dvc-s3 3.2.0, pathspec 0.11.2

---

## 3. Timing

| Phase              | Target                                                     |
|--------------------|------------------------------------------------------------|
| **Setup script**   | ~90–120 sec (apt-get + pip install + S3 bucket creation)   |
| **Test scripts**   | ~20–30 sec (10 GitHub/AWS API calls)                       |
| **Student work**   | ~75 min (DVC setup + code TODOs + push + wait for CI)      |

---

## 4. What the Setup Script Creates

| Resource                                   | Details                                                                              |
|--------------------------------------------|--------------------------------------------------------------------------------------|
| Python 3.8 + packages                      | mlflow, scikit-learn, dvc, boto3, pandas, matplotlib, seaborn, numpy                 |
| S3 bucket                                  | `wine-mlflow-dvc-<account_id>` in us-west-2 — used as DVC remote                    |
| AWS credentials                            | Container's own creds → `/home/user/aws_iam_creds.json`                              |
| Git config                                 | Default branch `main`, placeholder user.email/name                                   |
| `data/wine.csv`                            | Wine Quality dataset (178 rows, 14 columns)                                          |
| `train.py`                                 | Training script scaffold with 9 TODO placeholders                                    |
| `query_runs.py`                            | MlflowClient query script scaffold with 5 TODO placeholders                         |
| `run_experiments.sh`                       | Runs 7 model experiments (do not modify)                                             |
| `requirements.txt`                         | Pinned dependencies for GitHub Actions (Python 3.11)                                 |
| `.gitignore`                               | Ignores `mlruns/`, `data/wine.csv`, `.dvc/cache/`, `.dvc/tmp/`                       |
| `.github/workflows/train-pipeline.yml`     | Workflow scaffold with TODO comments                                                 |
| `/home/user/lab_env.txt`                   | S3_BUCKET, REGION, ACCOUNT_ID                                                        |
| `/home/user/setup_log.txt`                 | Step-by-step log with timestamps for debugging                                       |

**Zero EC2, zero ECR, zero IAM user creation.**

---

## 5. Test Cases (50 pts)

| #  | Pts | What it checks                                                                              |
|----|-----|----------------------------------------------------------------------------------------------|
| 01 | 5   | GitHub PAT is valid                                                                          |
| 02 | 5   | Repo exists; saves token/username/repo to `/var/tmp/`                                        |
| 03 | 5   | `.github/workflows/train-pipeline.yml` exists in repo; decoded to `/var/tmp/`                |
| 04 | 5   | Workflow name = `MLflow Training Pipeline`, triggers = push + dispatch                       |
| 05 | 5   | `.dvc/config` in repo points to `s3://<expected-bucket>`                                     |
| 06 | 5   | `data/wine.csv.dvc` committed AND S3 bucket contains DVC cache files                        |
| 07 | 5   | `train.py` contains all 6 required MLflow calls                                             |
| 08 | 5   | `query_runs.py` contains MlflowClient, get_experiment_by_name, search_runs                  |
| 09 | 5   | A successful `MLflow Training Pipeline` run exists                                           |
| 10 | 5   | Both `train` and `report` jobs completed successfully AND `mlruns-artifact` was produced     |

**Anti-cheat:** Test 10 verifies the `mlruns-artifact` was actually uploaded. A fake workflow with echo-only steps will pass job completion but fail the artifact check. This is direction-agnostic — students can wire the workflow any way they want as long as real experiments run and produce the artifact.

---

## 6. Common Student Issues

| Issue                                        | Root Cause                                                    | Fix                                                       |
|----------------------------------------------|---------------------------------------------------------------|------------------------------------------------------------|
| `dvc push` fails with `Access Denied`        | AWS env vars not exported before running DVC                  | Export all vars from `aws_iam_creds.json` first            |
| `dvc pull` fails in CI                       | AWS secrets not added to GitHub repo                          | Add all three secrets under Settings → Secrets → Actions   |
| `dvc init` fails — not tracked by SCM        | Running from `/home/user/` instead of project directory       | `cd /home/user/wine-mlflow` first                          |
| `git commit` fails — identity not set        | Should not happen (setup pre-configures git)                  | `git config --global user.email/name` if needed            |
| `git branch -M main` fails                   | Ran before first commit                                       | Commit first, then rename branch                           |
| Invalid workflow YAML on push                | Student pushed before completing the workflow                 | Complete the workflow TODO before pushing                   |
| `train.py` runs but nothing logged           | TODOs not wrapped inside `with mlflow.start_run()`            | The context manager must wrap all logging calls            |
| `report` job fails — experiment not found    | `mlruns/` artifact downloaded to wrong path                   | download-artifact step must set `path: mlruns`             |
| `PermissionError: /home/user` in CI          | `mlruns/` from local runs committed to git                    | Add `mlruns/` to .gitignore (already done by setup)        |
| `pathspec _DIR_MARK` import error in CI      | DVC + pathspec version incompatibility                        | `pathspec==0.11.2` is pinned in requirements.txt           |
| Test 05 fails — wrong bucket URL             | Student used a different bucket name                          | DVC remote URL must match the bucket in `lab_env.txt`      |

---

## 7. Key Design Decisions

**Local vs CI package versions:** The local container (Python 3.8) installs older compatible versions (scikit-learn 1.3.2, dvc 2.58.2). The `requirements.txt` for GitHub Actions (Python 3.11) uses newer versions (scikit-learn 1.5.2, dvc 3.51.2). The APIs used in this lab are identical across these versions.

**pathspec pin:** `pathspec==0.11.2` is pinned in requirements.txt because newer pathspec removed `_DIR_MARK` which some DVC versions still import.

**mlruns/ in .gitignore:** Pre-configured to prevent students from accidentally committing local experiment data, which would cause `PermissionError` in CI due to hardcoded `/home/user/` paths in MLflow metadata.

**Workflow scaffold has invalid YAML:** The scaffold uses `name: # TODO` and `on: # TODO` which are invalid. Students must complete the workflow before pushing, or push without the `.github/` directory first.

---

## 8. Cleanup

The platform's Stop Lab button destroys the container and AWS account, removing the S3 bucket automatically. No manual cleanup required.
