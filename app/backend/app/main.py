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
