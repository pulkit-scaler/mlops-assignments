# CI/CD Pipeline for MLOps Model Serving Platform — Lab Question

---

## Description

In this lab, you will work with a production-grade MLOps Model Serving Platform, verify it runs locally, and then build a complete CI/CD pipeline using GitHub Actions that builds Docker images, pushes them to Amazon ECR, and deploys the full stack to an EC2 instance.

The MLOps Model Serving Platform is a multi-service application consisting of:

- **FastAPI ML API** — serves predictions from a trained scikit-learn Iris classifier with Redis caching
- **Streamlit Dashboard** — interactive prediction UI and model performance monitoring
- **Redis** — prediction result cache layer for low-latency repeated queries

This lab simulates a real-world MLOps deployment scenario where a CI/CD workflow must:

- Build multiple Docker images from a monorepo (ML API + Dashboard)
- Authenticate with AWS and push images to a private container registry
- Deploy the full multi-container ML stack to a remote server over SSH
- Handle secrets, environment variables, and service dependencies correctly

You will learn how to orchestrate multi-job pipelines, work with AWS services from GitHub Actions, and perform remote deployments of ML applications.

---

## Prerequisites

The following resources are pre-provisioned and available to you in `us-west-2`:

- **AWS Account** with:
    - An ECR private repository named `mlops-api`
    
    - An ECR private repository named `mlops-dashboard`
    
    - An EC2 instance (Ubuntu) with Docker and Docker Compose installed and running in `us-west-2` region
    
    - An IAM user named `lab-check` with permissions for ECR push/pull operations

- **EC2 Instance Details:**

  - Docker and Docker Compose are pre-installed
  
  - The instance has port `8501` (Streamlit dashboard), `8000` (ML API), and `22` (SSH) open in its security group
  
  - You have SSH access via a private key

- **Pre-created Files on Your Machine:**

  - `/home/user/aws_iam_creds.json` — IAM access keys (AccessKeyId and SecretAccessKey)
  
  - `/home/user/private.pem` — EC2 SSH private key
  
  - `/home/user/lab_env.txt` — All environment details (source this for reference values)
  
  - `/home/user/mlops-model-serving/` — The application source code

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

### 2. Verify the Application Locally

The application source code is pre-created at `/home/user/mlops-model-serving/`. Start by verifying it works locally.

```bash
cd /home/user/mlops-model-serving
```

- Start the full stack locally to verify everything works:

```bash
docker compose up -d --build
```

- Verify the services are running:

```bash
# ML API health check — should return model loaded status and Redis connectivity
curl http://localhost:8000/health

# Model info — should return model metadata (name, version, accuracy, etc.)
curl http://localhost:8000/model/info

# Test a prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2}'
```

- Confirm the health endpoint returns a successful response with `model_loaded: true` and `redis_connected: true` before proceeding.

- Once verified, stop the local stack:

```bash
docker compose down
```

---

### 3. Push to Your GitHub Repository

Initialize and push the code to your own GitHub repository:

```bash
cd /home/user/mlops-model-serving
git init
git add .
git commit -m "Initial commit: MLOps Model Serving Platform"
git remote add origin https://github.com/<your_username>/<your_repo_name>.git
git branch -M main
git push -u origin main
```

---

### 4. Configure GitHub Repository Secrets

Navigate to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**, and add the following **Repository Secrets**:

```
| Secret Name             | Value                                                                     |
|---                      |---                                                                        |
| `AWS_ACCESS_KEY_ID`     | Your IAM user access key ID from `/home/user/aws_iam_creds.json`          |
| `AWS_SECRET_ACCESS_KEY` | Your IAM user secret access key from `/home/user/aws_iam_creds.json`      |
| `AWS_REGION`            | `us-west-2`                                                               |
| `AWS_ACCOUNT_ID`        | Your 12-digit AWS account ID (see `/home/user/lab_env.txt`)               |
| `EC2_HOST`              | Public IP of your EC2 instance (see `/home/user/lab_env.txt`)             |
| `EC2_SSH_KEY`           | The full contents of `/home/user/private.pem`                             |
| `EC2_USER`              | `ubuntu`                                                                  |
```

---

### 5. Create the Workflow File

- The workflow file must be named **`deploy-pipeline.yml`** and must exist at the path:

```
.github/workflows/deploy-pipeline.yml
```

- The workflow name must be: **`MLOps CI/CD Pipeline`**

- The workflow must trigger on:
    - **Push** to the `main` branch
  
    - **Manual trigger** using `workflow_dispatch`

---

### 6. Define Environment Variables

At the **top level** of the workflow (accessible to all jobs), define the following environment variables:

```
| Variable                | Value                                                                                  |
|---                      |---                                                                                     |
| `API_IMAGE_NAME`        | `mlops-api`                                                                            |
| `DASHBOARD_IMAGE_NAME`  | `mlops-dashboard`                                                                      |
| `IMAGE_TAG`             | Must dynamically use the short Git commit SHA (`github.sha` truncated to 7 characters) |
```

---

### 7. Implement the `build` Job

This job builds the Docker images for both the ML API and the Streamlit Dashboard.

**Runner:** `ubuntu-latest`

**Steps this job must perform:**

1. Check out the repository code
2. Set up Docker Buildx
3. Build the ML API Docker image

    - Context: `./backend`
    
    - Dockerfile: `./backend/Dockerfile`
    
    - The image must be tagged with both the commit SHA tag and `latest`
    
    - Tag format: `${{ env.API_IMAGE_NAME }}:<tag>`
    
    - The image must be loaded into the local Docker daemon (not pushed)
    
4. Build the Dashboard Docker image

    - Context: `./frontend`
    
    - Dockerfile: `./frontend/Dockerfile`
    
    - Same tagging strategy as the ML API
    
    - Tag format: `${{ env.DASHBOARD_IMAGE_NAME }}:<tag>`
    
    - The image must be loaded into the local Docker daemon (not pushed)

5. Save both built images as a **tar archive** so downstream jobs can use them
   
    - Use `docker save` to save all four image tags (api:sha, api:latest, dashboard:sha, dashboard:latest) into a single file named `mlops-images.tar`
    
    - Upload this file as a **GitHub Actions artifact** named `docker-images`

---

### 8. Implement the `push` Job

This job authenticates with AWS ECR and pushes the Docker images.

**Runner:** `ubuntu-latest`

**Dependency:** This job must run only after the `build` job completes successfully.

**Steps this job must perform:**

1. Download the `docker-images` artifact from the `build` job

2. Load the Docker images from the tar archive

3. Configure AWS credentials using the `aws-actions/configure-aws-credentials` GitHub Action
    
    - Use the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` secrets
   
4. Log in to Amazon ECR using the `aws-actions/amazon-ecr-login` GitHub Action

5. Tag and push the **ML API** image

    - Tag the locally built image for ECR: `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<API_IMAGE_NAME>:<IMAGE_TAG>` and the same with `latest`
    
    - Push both tags to ECR

6. Tag and push the **Dashboard** image
    
    - Same tagging and push strategy as the ML API

---

### 9. Implement the `deploy` Job

This job deploys the ML application to the EC2 instance over SSH.

**Runner:** `ubuntu-latest`

**Dependency:** This job must run only after the `push` job completes successfully.

**Steps this job must perform:**

1. Deploy to EC2 using the `appleboy/ssh-action` GitHub Action with the following SSH connection details:
    
    - `host`: from `EC2_HOST` secret
    
    - `username`: from `EC2_USER` secret
    
    - `key`: from `EC2_SSH_KEY` secret

2. The SSH script executed on the EC2 instance must perform the following operations **in order**:

   a. **Authenticate with ECR** — Log in to the ECR registry using the AWS CLI on the EC2 instance. Construct the registry URL as `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com`

   b. **Pull the latest images** — Pull both the ML API and Dashboard images using the commit SHA tag from ECR

   c. **Stop existing containers** — If a running stack exists, bring it down using `docker compose down`

   d. **Set environment variables** for the compose deployment — Export the following so that `docker-compose.deploy.yml` can reference them:
   
        - `ML_API_IMAGE` — full ECR URI for the ML API image with the commit SHA tag
        
        - `ML_DASHBOARD_IMAGE` — full ECR URI for the Dashboard image with the commit SHA tag

   e. **Start the stack** — Run `docker compose -f docker-compose.deploy.yml up -d`

   f. **Verify deployment** — Wait 10 seconds for services to initialize, then run `docker ps` to display running containers

   The environment variables `AWS_ACCOUNT_ID`, `AWS_REGION`, `API_IMAGE_NAME`, `DASHBOARD_IMAGE_NAME`, and `IMAGE_TAG` must be passed to the SSH script so that it can construct the full image URIs. Use the `envs` parameter of the `appleboy/ssh-action` to pass the workflow-level environment variables and secrets into the remote script.

---

### 10. Deployment Compose File

A **`docker-compose.deploy.yml`** file is already present on the EC2 instance at `/home/ubuntu/mlops-model-serving/`. It is identical to the local `docker-compose.yml` except that the ML API and Dashboard services use `image: ${ML_API_IMAGE}` and `image: ${ML_DASHBOARD_IMAGE}` instead of `build:` directives, and the local bind-mount volumes are removed. **No changes are needed — your deploy job will reference this file as-is.**

---

### 11. Trigger and Verify the Pipeline

1. Push your changes to the `main` branch (or trigger manually from the Actions tab)

2. Monitor the workflow execution in GitHub Actions

3. Verify that all three jobs complete successfully in sequence: `build → push → deploy`

4. After successful deployment, verify the application is accessible:

```bash
# ML API Health check (use EC2_PUBLIC_IP from lab_env.txt)
curl http://<EC2_PUBLIC_IP>:8000/health

# Model info
curl http://<EC2_PUBLIC_IP>:8000/model/info

# Test prediction
curl -X POST http://<EC2_PUBLIC_IP>:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length": 6.7, "sepal_width": 3.1, "petal_length": 4.7, "petal_width": 1.5}'

# Streamlit Dashboard — open in browser
# http://<EC2_PUBLIC_IP>:8501
```

---

## Your workflow must:

- Be named `MLOps CI/CD Pipeline`

- Trigger on push to `main` and on `workflow_dispatch`

- Use dynamic image tagging with the Git commit SHA (7 characters)

- Build both ML API and Dashboard Docker images in the `build` job

- Pass images between jobs using GitHub Actions artifacts

- Authenticate with AWS and push both images to ECR in the `push` job

- Deploy to EC2 over SSH in the `deploy` job

- Use proper job dependencies: `build → push → deploy`

- All three jobs must complete successfully

- The ML application must be accessible on the EC2 instance after deployment

---

## Outcomes

When executed correctly, GitHub Actions will show three jobs in sequence:

```
build  →  push  →  deploy
```

- The `build` job produces Docker images for the ML API and Dashboard, uploading them as artifacts

- The `push` job authenticates with AWS ECR and pushes the tagged images to both ECR repositories

- The `deploy` job SSHs into the EC2 instance, pulls the new images, and restarts the ML stack

- The MLOps Model Serving Platform is live and accessible on the EC2 instance:
  - ML API health check returns `model_loaded: true` and `redis_connected: true`
  - Model info endpoint returns training metrics (accuracy, F1 score)
  - Prediction endpoint returns Iris species classifications with confidence scores
  - Streamlit Dashboard is accessible for interactive predictions

**Skills practiced:**

- Multi-job GitHub Actions pipeline design for ML applications
- Docker image build and artifact passing between jobs
- AWS ECR authentication and image push
- Remote deployment of ML services over SSH
- Docker Compose orchestration for multi-service ML stacks
- Secrets management in CI/CD pipelines
- Environment variable propagation across jobs and remote hosts
