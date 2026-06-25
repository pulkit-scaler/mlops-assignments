# MLOps Assignments

Index of hands-on MLOps lab assignments. **Each assignment lives on its own branch** —
this `main` branch only holds this index. Click a branch link below to open the full
assignment (problem statement, setup, and grading scripts).

## Assignments

| # | Assignment | ID | Branch |
|---|------------|----|--------|
| 1 | **MLOps CI/CD Pipeline** — build a GitHub Actions CI/CD pipeline (build → push → deploy) for an ML model serving stack on ECR + EC2 | `301468` | [`mlops-ci-cd`](https://github.com/pulkit-scaler/mlops-assignments/tree/mlops-ci-cd) |
| 2 | **S3 & SageMaker Data Wrangler** — prepare the Iris dataset in Data Wrangler and export the processed CSV to S3 | `301607` | [`s3-data-wrangler`](https://github.com/pulkit-scaler/mlops-assignments/tree/s3-data-wrangler) |
| 3 | **SageMaker Feature Store** — create a feature group and ingest/retrieve Iris records via boto3 (online + offline store) | `301712` | [`feature-store`](https://github.com/pulkit-scaler/mlops-assignments/tree/feature-store) |
| 4 | **SageMaker Model Registry & Canvas** — train an Iris model in Canvas and share it to the registry, register a second version via boto3, and drive the approval workflow | `301766` | [`model-registry-canvas`](https://github.com/pulkit-scaler/mlops-assignments/tree/model-registry-canvas) |

## How this repo is organized

- **`main`** — this index only.
- **One branch per assignment** — named after the assignment, containing:
  - `problem-statement.md` — the lab question handed to learners
  - `setup/scripts/` — environment provisioning script(s)
  - `test-cases/scripts/` — auto-grading scripts

## Opening an assignment

```bash
git clone git@github.com:pulkit-scaler/mlops-assignments.git
cd mlops-assignments
git switch mlops-ci-cd        # or: s3-data-wrangler, feature-store, model-registry-canvas
```
