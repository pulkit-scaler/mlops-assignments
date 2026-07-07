#!/bin/bash

set -euo pipefail
BASE_DIR="/home/user/mlops-model-serving"
REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "================================================"
echo "MLOps CI/CD Pipeline Lab - Setup"
echo "================================================"
echo "Region: ${REGION} | Account: ${ACCOUNT_ID}"
echo ""

# ==========================================
# 1. Create ECR Repositories (parallel)
# ==========================================
echo "[1/5] Creating ECR Repositories..."

aws ecr create-repository --repository-name mlops-api --region "$REGION" 2>/dev/null &
PID1=$!
aws ecr create-repository --repository-name mlops-dashboard --region "$REGION" 2>/dev/null &
PID2=$!
wait $PID1 2>/dev/null || echo "  mlops-api already exists"
wait $PID2 2>/dev/null || echo "  mlops-dashboard already exists"

echo "  ✓ ECR: mlops-api, mlops-dashboard"

# ==========================================
# 2. Save AWS Credentials (reuse container's own creds)
# ==========================================
echo "[2/5] Saving AWS credentials..."

if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    CRED_KEY="$AWS_ACCESS_KEY_ID"
    CRED_SECRET="$AWS_SECRET_ACCESS_KEY"
    CRED_TOKEN="${AWS_SESSION_TOKEN:-}"
else
    CRED_KEY=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
    CRED_SECRET=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
    CRED_TOKEN=$(aws configure get aws_session_token 2>/dev/null || echo "")
fi

if [ -z "$CRED_KEY" ] || [ -z "$CRED_SECRET" ]; then
    echo "  ERROR: Could not extract AWS credentials"
    exit 1
fi

if [ -n "$CRED_TOKEN" ]; then
    cat > /home/user/aws_iam_creds.json <<CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}",
  "SessionToken": "${CRED_TOKEN}"
}
CREDS
    echo "  ✓ Credentials saved (includes session token)"
else
    cat > /home/user/aws_iam_creds.json <<CREDS
{
  "AccessKeyId": "${CRED_KEY}",
  "SecretAccessKey": "${CRED_SECRET}"
}
CREDS
    echo "  ✓ Credentials saved"
fi
chmod 600 /home/user/aws_iam_creds.json

# ==========================================
# 3. Create Key Pair + Security Group
# ==========================================
echo "[3/5] Setting up EC2 networking..."

KEY_NAME="mlops-lab-key"
SG_NAME="mlops-lab-sg"

aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" 2>/dev/null || true
aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" \
    --query 'KeyMaterial' --output text > /home/user/private.pem
chmod 600 /home/user/private.pem

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" \
    --region "$REGION" --query 'Vpcs[0].VpcId' --output text)

SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --region "$REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group --group-name "$SG_NAME" \
        --description "MLOps Lab" --vpc-id "$VPC_ID" --region "$REGION" \
        --query 'GroupId' --output text)
    for PORT in 22 8000 8501; do
        aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
            --protocol tcp --port "$PORT" --cidr 0.0.0.0/0 \
            --region "$REGION" 2>/dev/null || true
    done
fi

echo "  ✓ Key pair: $KEY_NAME | SG: $SG_ID"

# ==========================================
# 4. Launch EC2 t2.micro (user-data handles all config)
# ==========================================
echo "[4/5] Launching EC2 instance..."

AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --region "$REGION" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)

if [ -n "$CRED_TOKEN" ]; then
    AWS_CREDS_BLOCK="[default]
aws_access_key_id = ${CRED_KEY}
aws_secret_access_key = ${CRED_SECRET}
aws_session_token = ${CRED_TOKEN}"
else
    AWS_CREDS_BLOCK="[default]
aws_access_key_id = ${CRED_KEY}
aws_secret_access_key = ${CRED_SECRET}"
fi

USER_DATA=$(cat <<USERDATA
#!/bin/bash
set -e

# Add 2GB swap (t2.micro only has 1GB RAM)
dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Install Docker
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common unzip
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable docker && systemctl start docker

# Install AWS CLI v2
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip

# Configure AWS credentials for ECR access
mkdir -p /home/ubuntu/.aws
cat > /home/ubuntu/.aws/credentials <<'AWSCRED'
${AWS_CREDS_BLOCK}
AWSCRED
cat > /home/ubuntu/.aws/config <<AWSCFG
[default]
region = ${REGION}
AWSCFG
chown -R ubuntu:ubuntu /home/ubuntu/.aws

# Create deployment workspace + compose file
mkdir -p /home/ubuntu/mlops-model-serving
cat > /home/ubuntu/mlops-model-serving/docker-compose.deploy.yml <<'COMPOSEFILE'
version: "3.8"
services:
  ml-api:
    image: \${ML_API_IMAGE}
    ports: ["8000:8000"]
    environment: [REDIS_HOST=redis, REDIS_PORT=6379, CACHE_TTL=300]
    depends_on: [redis]
    restart: unless-stopped
  ml-dashboard:
    image: \${ML_DASHBOARD_IMAGE}
    ports: ["8501:8501"]
    environment: [API_URL=http://ml-api:8000]
    depends_on: [ml-api]
    restart: unless-stopped
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    restart: unless-stopped
COMPOSEFILE
chown -R ubuntu:ubuntu /home/ubuntu/mlops-model-serving
USERDATA
)

EXISTING=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=mlops-lab-instance" \
              "Name=instance-state-name,Values=running,pending" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "None")

if [ "$EXISTING" = "None" ] || [ -z "$EXISTING" ]; then
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" --instance-type t2.micro \
        --key-name "$KEY_NAME" --security-group-ids "$SG_ID" \
        --user-data "$USER_DATA" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=mlops-lab-instance}]" \
        --region "$REGION" --query 'Instances[0].InstanceId' --output text)
    echo "  Instance launched: $INSTANCE_ID"
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
else
    INSTANCE_ID="$EXISTING"
    echo "  Instance already exists: $INSTANCE_ID"
fi

EC2_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --region "$REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "  ✓ EC2: $EC2_PUBLIC_IP (Docker installing in background ~3-5 min)"

# ==========================================
# 5. Create Application Code + Save Env
# ==========================================
echo "[5/5] Creating application code..."

mkdir -p ${BASE_DIR}/backend/app ${BASE_DIR}/backend/models ${BASE_DIR}/frontend

cat > ${BASE_DIR}/backend/train_model.py <<'PYEOF'
import pickle, json, os
from datetime import datetime
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score

def train_and_save():
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(iris.data, iris.target, test_size=0.2, random_state=42)
    model = RandomForestClassifier(n_estimators=100, max_depth=5, random_state=42)
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred, average="weighted")
    os.makedirs("/app/models", exist_ok=True)
    with open("/app/models/iris_model.pkl", "wb") as f:
        pickle.dump(model, f)
    metadata = {
        "model_name": "iris-classifier", "model_version": "1.0.0",
        "algorithm": "RandomForestClassifier", "n_estimators": 100, "max_depth": 5,
        "training_accuracy": round(accuracy, 4), "training_f1_score": round(f1, 4),
        "feature_names": iris.feature_names, "target_names": list(iris.target_names),
        "trained_at": datetime.utcnow().isoformat(), "framework": "scikit-learn"
    }
    with open("/app/models/model_metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"Model saved — accuracy: {accuracy:.4f}, f1: {f1:.4f}")

if __name__ == "__main__":
    train_and_save()
PYEOF

touch ${BASE_DIR}/backend/app/__init__.py

cat > ${BASE_DIR}/backend/app/schemas.py <<'PYEOF'
from pydantic import BaseModel, Field
from typing import List, Optional

class PredictionRequest(BaseModel):
    sepal_length: float = Field(..., ge=0, le=10)
    sepal_width: float = Field(..., ge=0, le=10)
    petal_length: float = Field(..., ge=0, le=10)
    petal_width: float = Field(..., ge=0, le=10)

class PredictionResponse(BaseModel):
    prediction: str
    prediction_id: int
    confidence: float
    probabilities: dict

class BatchPredictionRequest(BaseModel):
    instances: List[PredictionRequest]

class BatchPredictionResponse(BaseModel):
    predictions: List[PredictionResponse]
    count: int

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    redis_connected: bool
    model_version: Optional[str] = None

class ModelInfoResponse(BaseModel):
    model_name: str
    model_version: str
    algorithm: str
    training_accuracy: float
    training_f1_score: float
    feature_names: List[str]
    target_names: List[str]
    framework: str
    trained_at: str
PYEOF

cat > ${BASE_DIR}/backend/app/model.py <<'PYEOF'
import pickle, json, os, logging
logger = logging.getLogger(__name__)
MODEL_PATH = os.getenv("MODEL_PATH", "/app/models/iris_model.pkl")
METADATA_PATH = os.getenv("METADATA_PATH", "/app/models/model_metadata.json")
_model = None
_metadata = None

def load_model():
    global _model, _metadata
    try:
        with open(MODEL_PATH, "rb") as f: _model = pickle.load(f)
    except Exception as e:
        logger.error(f"Failed to load model: {e}"); _model = None
    try:
        with open(METADATA_PATH, "r") as f: _metadata = json.load(f)
    except Exception as e:
        logger.error(f"Failed to load metadata: {e}"); _metadata = None

def get_model(): return _model
def get_metadata(): return _metadata
def is_model_loaded(): return _model is not None
PYEOF

cat > ${BASE_DIR}/backend/app/main.py <<'PYEOF'
import os, json, hashlib, logging
from contextlib import asynccontextmanager
import numpy as np
import redis
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.model import load_model, get_model, get_metadata, is_model_loaded
from app.schemas import (PredictionRequest, PredictionResponse, BatchPredictionRequest,
                         BatchPredictionResponse, HealthResponse, ModelInfoResponse)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
CACHE_TTL = int(os.getenv("CACHE_TTL", "300"))
redis_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global redis_client
    load_model()
    try:
        redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
        redis_client.ping()
    except Exception: redis_client = None
    yield
    if redis_client: redis_client.close()

app = FastAPI(title="MLOps Prediction Service", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

def _predict_single(req: PredictionRequest) -> PredictionResponse:
    model, metadata = get_model(), get_metadata()
    if model is None: raise HTTPException(status_code=503, detail="Model not loaded")
    features = [[req.sepal_length, req.sepal_width, req.petal_length, req.petal_width]]
    cache_key = f"pred:{hashlib.md5(json.dumps(features[0], sort_keys=True).encode()).hexdigest()}"
    if redis_client:
        try:
            cached = redis_client.get(cache_key)
            if cached: return PredictionResponse(**json.loads(cached))
        except Exception: pass
    pred_id = int(model.predict(features)[0])
    probs = model.predict_proba(features)[0]
    names = metadata["target_names"] if metadata else [str(i) for i in range(3)]
    result = PredictionResponse(prediction=names[pred_id], prediction_id=pred_id,
        confidence=round(float(np.max(probs)), 4),
        probabilities={names[i]: round(float(p), 4) for i, p in enumerate(probs)})
    if redis_client:
        try: redis_client.setex(cache_key, CACHE_TTL, result.model_dump_json())
        except Exception: pass
    return result

@app.get("/health", response_model=HealthResponse)
async def health_check():
    redis_ok = False
    if redis_client:
        try: redis_client.ping(); redis_ok = True
        except Exception: pass
    metadata = get_metadata()
    return HealthResponse(status="healthy" if is_model_loaded() and redis_ok else "degraded",
        model_loaded=is_model_loaded(), redis_connected=redis_ok,
        model_version=metadata.get("model_version") if metadata else None)

@app.get("/model/info", response_model=ModelInfoResponse)
async def model_info():
    metadata = get_metadata()
    if not metadata: raise HTTPException(status_code=503, detail="Metadata not available")
    return ModelInfoResponse(**metadata)

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest): return _predict_single(request)

@app.post("/predict/batch", response_model=BatchPredictionResponse)
async def predict_batch(request: BatchPredictionRequest):
    if len(request.instances) > 100: raise HTTPException(400, "Max 100 instances")
    results = [_predict_single(i) for i in request.instances]
    return BatchPredictionResponse(predictions=results, count=len(results))

@app.get("/")
async def root(): return {"service": "MLOps Prediction Service", "version": "1.0.0"}
PYEOF

cat > ${BASE_DIR}/backend/requirements.txt <<'EOF'
fastapi==0.115.0
uvicorn==0.30.6
scikit-learn==1.5.2
numpy==1.26.4
redis==5.0.8
pydantic==2.9.2
EOF

cat > ${BASE_DIR}/backend/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN python train_model.py
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > ${BASE_DIR}/frontend/app.py <<'PYEOF'
import os, requests, streamlit as st
API_URL = os.getenv("API_URL", "http://ml-api:8000")
st.set_page_config(page_title="MLOps Prediction Dashboard", page_icon="🤖", layout="wide")
st.title("🤖 MLOps Prediction Dashboard")
try:
    health = requests.get(f"{API_URL}/health", timeout=5).json()
    if health["status"] == "healthy":
        st.success(f"✅ API Healthy — Model v{health.get('model_version', 'N/A')}")
    else: st.warning(f"⚠️ Degraded")
except Exception as e: st.error(f"❌ API Unreachable: {e}")
st.divider()
st.subheader("Make a Prediction")
c1, c2, c3, c4 = st.columns(4)
with c1: sl = st.number_input("Sepal Length", 0.0, 10.0, 5.1, 0.1)
with c2: sw = st.number_input("Sepal Width", 0.0, 10.0, 3.5, 0.1)
with c3: pl = st.number_input("Petal Length", 0.0, 10.0, 1.4, 0.1)
with c4: pw = st.number_input("Petal Width", 0.0, 10.0, 0.2, 0.1)
if st.button("🔮 Predict", type="primary"):
    try:
        r = requests.post(f"{API_URL}/predict", json={"sepal_length":sl,"sepal_width":sw,"petal_length":pl,"petal_width":pw}, timeout=10).json()
        st.metric("Species", r["prediction"])
        st.metric("Confidence", f"{r['confidence']:.2%}")
        for sp, p in r["probabilities"].items(): st.progress(p, text=f"{sp}: {p:.2%}")
    except Exception as e: st.error(f"Failed: {e}")
PYEOF

cat > ${BASE_DIR}/frontend/requirements.txt <<'EOF'
streamlit==1.38.0
requests==2.32.3
EOF

cat > ${BASE_DIR}/frontend/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8501
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.headless=true"]
EOF

cat > ${BASE_DIR}/docker-compose.yml <<'EOF'
version: "3.8"
services:
  ml-api:
    build: { context: ./backend, dockerfile: Dockerfile }
    ports: ["8000:8000"]
    environment: [REDIS_HOST=redis, REDIS_PORT=6379, CACHE_TTL=300]
    depends_on: [redis]
    restart: unless-stopped
  ml-dashboard:
    build: { context: ./frontend, dockerfile: Dockerfile }
    ports: ["8501:8501"]
    environment: [API_URL=http://ml-api:8000]
    depends_on: [ml-api]
    restart: unless-stopped
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    restart: unless-stopped
EOF

cat > ${BASE_DIR}/docker-compose.deploy.yml <<'EOF'
version: "3.8"
services:
  ml-api:
    image: ${ML_API_IMAGE}
    ports: ["8000:8000"]
    environment: [REDIS_HOST=redis, REDIS_PORT=6379, CACHE_TTL=300]
    depends_on: [redis]
    restart: unless-stopped
  ml-dashboard:
    image: ${ML_DASHBOARD_IMAGE}
    ports: ["8501:8501"]
    environment: [API_URL=http://ml-api:8000]
    depends_on: [ml-api]
    restart: unless-stopped
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    restart: unless-stopped
EOF

cat > ${BASE_DIR}/.gitignore <<'EOF'
__pycache__/
*.pyc
.env
.venv/
*.egg-info/
.DS_Store
EOF

cat > ${BASE_DIR}/README.md <<'EOF'
# MLOps Model Serving Platform
FastAPI ML API + Streamlit Dashboard + Redis cache.
```bash
docker compose up -d --build
curl http://localhost:8000/health
# Dashboard: http://localhost:8501
```
EOF

# ==========================================
# Add user to docker group so they can run docker without sudo
# ==========================================
usermod -aG docker user 2>/dev/null || true

# Save environment info
cat > /home/user/lab_env.txt <<ENV
REGION=${REGION}
ACCOUNT_ID=${ACCOUNT_ID}
EC2_PUBLIC_IP=${EC2_PUBLIC_IP}
EC2_INSTANCE_ID=${INSTANCE_ID}
EC2_USER=ubuntu
HAS_SESSION_TOKEN=$([ -n "$CRED_TOKEN" ] && echo "yes" || echo "no")
ENV

chown -R user:user ${BASE_DIR}
chown user:user /home/user/lab_env.txt /home/user/aws_iam_creds.json /home/user/private.pem

echo "  ✓ Application code + env info saved"

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "  ✓ ECR repos:    mlops-api, mlops-dashboard"
echo "  ✓ AWS creds:    /home/user/aws_iam_creds.json"
echo "  ✓ EC2 instance: $EC2_PUBLIC_IP (Docker installing ~3-5 min)"
echo "  ✓ SSH key:      /home/user/private.pem"
echo "  ✓ App code:     ${BASE_DIR}"
echo "  ✓ Docker group: user added (no sudo needed)"
echo ""
echo "  GitHub Secrets:"
echo "    AWS_ACCESS_KEY_ID     = $CRED_KEY"
echo "    AWS_SECRET_ACCESS_KEY = (see /home/user/aws_iam_creds.json)"
echo "    AWS_REGION            = $REGION"
echo "    AWS_ACCOUNT_ID        = $ACCOUNT_ID"
echo "    EC2_HOST              = $EC2_PUBLIC_IP"
echo "    EC2_USER              = ubuntu"
echo "    EC2_SSH_KEY           = (see /home/user/private.pem)"
if [ -n "$CRED_TOKEN" ]; then
echo "    AWS_SESSION_TOKEN     = (see /home/user/aws_iam_creds.json)"
fi
echo ""
echo "================================================"
