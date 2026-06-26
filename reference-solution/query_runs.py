"""
Query MLflow Runs — REFERENCE SOLUTION
"""

import mlflow
from mlflow.tracking import MlflowClient

# TODO 1 ✓
mlflow.set_tracking_uri("file:./mlruns")

# TODO 2 ✓
client = MlflowClient()

# TODO 3 ✓
experiment = client.get_experiment_by_name("wine-quality-classification")

if experiment is None:
    print("Experiment not found. Did you run train.py at least once?")
else:
    # TODO 4 ✓
    runs = client.search_runs(
        experiment_ids=[experiment.experiment_id],
        order_by=["metrics.accuracy DESC"],
    )

    # TODO 5 ✓
    print("\nTop 5 runs by accuracy:\n")
    for i, run in enumerate(runs[:5], 1):
        name = run.data.tags.get("mlflow.runName", "unnamed")
        acc  = run.data.metrics.get("accuracy", 0.0)
        f1   = run.data.metrics.get("f1_score", 0.0)
        print(f"{i}. {name}")
        print(f"   Accuracy : {acc:.4f}")
        print(f"   F1 Score : {f1:.4f}")
        print(f"   Params   : {run.data.params}")
        print()
