# MLflow + DVC Experiment Tracking Lab

**Assignment ID:** `302025`

A hands-on lab where learners build a reproducible, versioned ML workflow for a wine
quality producer using **DVC** for data versioning, **MLflow** for experiment tracking,
and **GitHub Actions** to run the training pipeline automatically on every push.

Learners:

1. Version the wine dataset with **DVC** and push it to an **S3** remote
2. Complete a `train.py` that logs params, metrics, and artifacts to **MLflow**
3. Run a sweep of experiments and complete a `query_runs.py` that ranks runs by accuracy
4. Wire up a **GitHub Actions** workflow that pulls the DVC data and runs the pipeline on push

This simulates a real-world MLOps workflow: data is versioned and reproducible across
environments, every training run is tracked and comparable, and the whole pipeline runs
automatically in CI.

## Repository Layout

| Path | What it contains |
|---|---|
| [`problem-statement.md`](problem-statement.md) | The full lab question handed to learners |
| [`INSTRUCTOR-SETUP-GUIDE.md`](INSTRUCTOR-SETUP-GUIDE.md) | Platform configuration, timing, scoring, and grading notes |
| [`setup/scripts/`](setup/scripts/) | Environment provisioning script (packages, S3 DVC remote, scaffold, credentials) |
| [`test-cases/scripts/`](test-cases/scripts/) | 10 auto-grading scripts |
| [`reference-solution/`](reference-solution/) | Reference `train.py`, `query_runs.py`, and `train-pipeline.yml` |

## Lab Overview

- **Cloud:** AWS `us-west-2` (S3 as the DVC remote)
- **Stack:** Python 3, MLflow, scikit-learn, DVC + dvc-s3, GitHub Actions
- Learners produce a DVC-tracked dataset on S3, MLflow runs comparing model configs,
  a working `query_runs.py`, and a green GitHub Actions training pipeline.

See [`problem-statement.md`](problem-statement.md) for the full task breakdown.

---

> Part of the [MLOps Assignments](https://github.com/pulkit-scaler/mlops-assignments) repo.
> The index of all assignments lives on the [`main`](https://github.com/pulkit-scaler/mlops-assignments/tree/main) branch.
