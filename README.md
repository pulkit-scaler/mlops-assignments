# S3 & SageMaker Data Wrangler — Data Preparation Lab

**Assignment ID:** `301607`

A hands-on lab where learners use **Amazon SageMaker Data Wrangler** to prepare the
classic Iris dataset for an ML pipeline: load raw data from **S3**, apply three feature
engineering transformations in the Data Wrangler visual interface, and export the
processed dataset back to S3.

This simulates the first stage of a real-world MLOps pipeline — structured, reproducible
data preparation whose output is versioned in S3 and handed off to downstream training jobs.

## Repository Layout

| Path | What it contains |
|---|---|
| [`problem-statement.md`](problem-statement.md) | The full lab question handed to learners |
| [`setup/scripts/`](setup/scripts/) | Environment provisioning script (S3 bucket, raw data, IAM role, Studio bootstrap) |
| [`test-cases/scripts/`](test-cases/scripts/) | 10 auto-grading scripts |

## Lab Overview

- **Cloud:** AWS `us-west-2` (S3 + SageMaker Studio / Canvas / Data Wrangler)
- Learners produce a processed CSV at `s3://.../processed-data/` with the target column
  renamed and ordinal-encoded.

See [`problem-statement.md`](problem-statement.md) for the full task breakdown.

---

> Part of the [MLOps Assignments](https://github.com/pulkit-scaler/mlops-assignments) repo.
> The index of all assignments lives on the [`main`](https://github.com/pulkit-scaler/mlops-assignments/tree/main) branch.
