# MLOps CI/CD Pipeline Lab

**Assignment ID:** `301468`

A hands-on lab where learners build a complete **CI/CD pipeline with GitHub Actions** for a
production-style **MLOps Model Serving Platform** — building Docker images, pushing them to
Amazon ECR, and deploying a multi-service ML stack to an EC2 instance over SSH.

The application under test is a multi-service stack:

- **FastAPI ML API** — serves predictions from a trained scikit-learn Iris classifier with Redis caching
- **Streamlit Dashboard** — interactive prediction UI and model monitoring
- **Redis** — prediction result cache layer

## Repository Layout

| Path | What it contains |
|---|---|
| [`problem-statement.md`](problem-statement.md) | The full lab question handed to learners |
| [`INSTRUCTOR-SETUP-GUIDE.md`](INSTRUCTOR-SETUP-GUIDE.md) | Platform configuration, timing, scoring, and grading notes |
| [`app/`](app/) | The MLOps Model Serving Platform source (backend, frontend, compose files) |
| [`setup/scripts/`](setup/scripts/) | Environment provisioning script (ECR repos, EC2, credentials, code) |
| [`test-cases/scripts/`](test-cases/scripts/) | 10 auto-grading scripts (5 pts each, 50 total) |
| [`reference-solution/`](reference-solution/) | Reference `deploy-pipeline.yml` GitHub Actions workflow |

## Lab Overview

- **Max score:** 50 (10 test cases × 5 pts)
- **Time limit:** 40 minutes (75 minute duration)
- **Cloud:** AWS `us-west-2` (ECR + EC2 t2.micro)

Learners produce a GitHub Actions workflow with three sequential jobs:

```
build  →  push  →  deploy
```

See [`problem-statement.md`](problem-statement.md) for the full task breakdown and
[`INSTRUCTOR-SETUP-GUIDE.md`](INSTRUCTOR-SETUP-GUIDE.md) for the grading rubric.

## Running the App Locally

```bash
cd app
docker compose up -d --build
curl http://localhost:8000/health      # ML API health
# Dashboard: http://localhost:8501
docker compose down
```

---

> Part of the [MLOps Assignments](https://github.com/pulkit-scaler/mlops-assignments) repo.
> The index of all assignments lives on the [`main`](https://github.com/pulkit-scaler/mlops-assignments/tree/main) branch.
