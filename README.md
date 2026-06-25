# SageMaker Feature Store — Ingest & Retrieve Lab

**Assignment ID:** `301712`

A hands-on lab where learners work with **Amazon SageMaker Feature Store**, the managed
feature repository for storing, sharing, and reusing ML features across training and
inference pipelines.

Learners:

1. Create a **Feature Group** (online + offline store) for the Iris dataset via the AWS CLI
2. Write a **boto3** script to ingest 20 records with `put_record()`
3. Retrieve all 20 records from the **online store** with `get_record()` and save them to JSON

This simulates a real-world MLOps workflow: a data engineering team publishes features to a
central store, and ML engineers consume them for both offline training and online inference.

## Repository Layout

| Path | What it contains |
|---|---|
| [`problem-statement.md`](problem-statement.md) | The full lab question handed to learners |
| [`INSTRUCTOR-SETUP-GUIDE.md`](INSTRUCTOR-SETUP-GUIDE.md) | Platform configuration, timing, scoring, and grading notes |
| [`setup/scripts/`](setup/scripts/) | Environment provisioning script (S3 offline store, credentials, sample data) |
| [`test-cases/scripts/`](test-cases/scripts/) | 10 auto-grading scripts |
| [`reference-solution/`](reference-solution/) | Reference `ingest_features.py` and a `solution.md` walkthrough |

## Lab Overview

- **Cloud:** AWS `us-west-2` (SageMaker Feature Store + S3)
- Learners produce an `iris-features` feature group (status `Created`) and a
  `retrieved_records.json` containing 20 records read back from the online store.

See [`problem-statement.md`](problem-statement.md) for the full task breakdown.

---

> Part of the [MLOps Assignments](https://github.com/pulkit-scaler/mlops-assignments) repo.
> The index of all assignments lives on the [`main`](https://github.com/pulkit-scaler/mlops-assignments/tree/main) branch.
