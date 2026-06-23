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
