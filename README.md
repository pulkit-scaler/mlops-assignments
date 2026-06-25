# SageMaker Model Registry & Canvas — Lab

**Assignment ID:** `301766`

A hands-on lab where learners work with the **Amazon SageMaker Model Registry**, the central
hub for cataloging trained models, tracking versions, and governing them through a formal
approval workflow — combined with **SageMaker Canvas** for no-code model training.

Learners:

1. Provision a **SageMaker Studio domain** (via a helper script) and train an Iris classifier
   in **Canvas** with no code
2. Create a **Model Package Group** to organize model versions via the AWS CLI
3. **Share** the Canvas-trained model into the registry directly from the Canvas UI
4. Register a second model version programmatically with **boto3**, specifying the inference
   container and model artifact
5. Manage the **approval workflow** — transition the boto3 version from
   `PendingManualApproval` to `Approved`
6. Save structured registration details to `registration_details.json` for audit

This simulates a real-world MLOps governance scenario: models arrive in a central registry from
multiple sources — no-code tools like Canvas and programmatic pipelines — and are governed
through a single approval process.

## Repository Layout

| Path | What it contains |
|---|---|
| [`problem-statement.md`](problem-statement.md) | The full lab question handed to learners |
| [`INSTRUCTOR-SETUP-GUIDE.md`](INSTRUCTOR-SETUP-GUIDE.md) | Platform configuration, timing, scoring, and grading notes |
| [`setup/scripts/`](setup/scripts/) | Environment provisioning script (S3 model artifact + dataset, IAM role, Studio helper, credentials) |
| [`test-cases/scripts/`](test-cases/scripts/) | 10 auto-grading scripts |
| [`reference-solution/`](reference-solution/) | Reference `register_model.py` and a `solution.md` walkthrough |

## Lab Overview

- **Cloud:** AWS `us-west-2` (SageMaker Studio + Canvas + Model Registry + S3)
- Learners produce an `iris-model-group` Model Package Group containing **two versions** (one
  from Canvas, one from boto3 — `Approved`) and a `registration_details.json` capturing both
  model package ARNs and the approval status.

See [`problem-statement.md`](problem-statement.md) for the full task breakdown.

---

> Part of the [MLOps Assignments](https://github.com/pulkit-scaler/mlops-assignments) repo.
> The index of all assignments lives on the [`main`](https://github.com/pulkit-scaler/mlops-assignments/tree/main) branch.
