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
