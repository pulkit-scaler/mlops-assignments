# MLOps CI/CD Pipeline Lab — Instructor Setup Guide

## 1. Platform Configuration

| Setting | Value |
|---|---|
| **Setup file** | `Setup.zip` |
| **Test Case Zip** | `TestCase.zip` |
| **Max Score** | 50 |
| **Time Limit** | 40 minutes |
| **Duration** | 75 minutes |

### AWS Policy to Select
- ✅ **DSML playground policy**

Provides `ec2:*`, `ecr:*`, `sts:*` in us-west-2. No IAM permissions needed — the setup script reuses the container's own AWS credentials.

### Policy Constraints Handled

| Constraint | How We Handle It |
|---|---|
| EC2 locked to `t2.micro` | Use t2.micro + 2GB swap file via user-data |
| Various IAM actions denied | **No IAM calls at all** — reuse container's existing credentials |

---

## 2. Timing

| Phase | Target |
|---|---|
| **Setup script** | ~90-120 sec (ECR repos + EC2 launch, no SSH wait) |
| **Test scripts** | ~20-30 sec (10 API calls) |
| **EC2 background** | ~3-5 min (Docker installs via user-data while student works) |

---

## 3. What the Setup Script Creates

| Resource | Details |
|---|---|
| ECR Repositories | `mlops-api` + `mlops-dashboard` |
| AWS Credentials | Container's own creds → `/home/user/aws_iam_creds.json` |
| EC2 Instance | Ubuntu t2.micro + 2GB swap, Docker via user-data |
| SSH Key Pair | `/home/user/private.pem` |
| Security Group | Ports 22, 8000, 8501 |
| Application Code | `/home/user/mlops-model-serving/` |
| Environment Info | `/home/user/lab_env.txt` |

**Zero IAM user/group/role creation.** Container's credentials are reused directly.

---

## 4. Test Cases (50 pts)

| # | Pts | Tests |
|---|---|---|
| 01 | 5 | GitHub credentials valid |
| 02 | 5 | Repository exists |
| 03 | 5 | Workflow file at `.github/workflows/deploy-pipeline.yml` |
| 04 | 5 | Name = `MLOps CI/CD Pipeline`, triggers = push + dispatch |
| 05 | 5 | Env vars: `API_IMAGE_NAME`, `DASHBOARD_IMAGE_NAME`, `IMAGE_TAG` |
| 06 | 5 | 3 jobs: `build → push → deploy` |
| 07 | 5 | Uses ECR login + SSH deploy actions |
| 08 | 5 | Successful workflow run exists |
| 09 | 5 | All 3 jobs completed |
| 10 | 5 | ECR images exist in both repos |

---

## 5. Session Token Note

If the platform provides temporary STS credentials, the setup script detects the session token and tells the student to add `AWS_SESSION_TOKEN` as an extra GitHub secret. The `aws-actions/configure-aws-credentials` action accepts `aws-session-token` as an optional parameter.
