"""
Wine Quality Classification - MLflow Experiment Tracking
REFERENCE SOLUTION
"""

import argparse
import os
import tempfile
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd

import mlflow
import mlflow.sklearn
from mlflow.models import infer_signature

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.svm import SVC
from sklearn.metrics import (
    accuracy_score, f1_score, precision_score, recall_score, confusion_matrix,
)

DATA_PATH = "data/wine.csv"


def load_data():
    df = pd.read_csv(DATA_PATH)
    X = df.drop("target", axis=1).values
    y = df["target"].values
    feature_names = df.drop("target", axis=1).columns.tolist()
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)
    return X_train_s, X_test_s, y_train, y_test, feature_names


def build_model(args):
    if args.model == "random-forest":
        params = {"n_estimators": args.n_estimators, "max_depth": args.max_depth, "random_state": 42}
        model = RandomForestClassifier(**params)
    elif args.model == "logistic-regression":
        params = {"C": args.C, "penalty": "l2", "solver": "lbfgs", "max_iter": 1000, "random_state": 42}
        model = LogisticRegression(**params)
    elif args.model == "svm":
        params = {"kernel": args.kernel, "C": args.C, "gamma": "scale", "random_state": 42}
        model = SVC(**params)
    else:
        raise ValueError(f"Unknown model: {args.model}")
    return model, params


def save_confusion_matrix(y_test, y_pred, path):
    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(7, 5))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues")
    plt.title("Confusion Matrix")
    plt.ylabel("True Label")
    plt.xlabel("Predicted Label")
    plt.tight_layout()
    plt.savefig(path)
    plt.close()


def run_experiment(args):
    X_train, X_test, y_train, y_test, feature_names = load_data()
    model, params = build_model(args)

    # TODO 1 ✓
    mlflow.set_tracking_uri("file:./mlruns")

    # TODO 2 ✓
    mlflow.set_experiment("wine-quality-classification")

    if args.model == "random-forest":
        run_name = f"rf-depth{args.max_depth}-trees{args.n_estimators}"
    elif args.model == "logistic-regression":
        run_name = f"lr-C{args.C}"
    else:
        run_name = f"svm-{args.kernel}"

    # TODO 3 ✓
    with mlflow.start_run(run_name=run_name):

        # TODO 4 ✓
        mlflow.log_params(params)
        mlflow.log_param("model_type", model.__class__.__name__)
        mlflow.log_param("data_scaling", "StandardScaler")

        # TODO 5 ✓
        t0 = time.time()
        model.fit(X_train, y_train)
        training_time = time.time() - t0
        y_pred = model.predict(X_test)
        accuracy  = accuracy_score(y_test, y_pred)
        f1        = f1_score(y_test, y_pred, average="weighted")
        precision = precision_score(y_test, y_pred, average="weighted", zero_division=0)
        recall    = recall_score(y_test, y_pred, average="weighted", zero_division=0)

        # TODO 6 ✓
        mlflow.log_metrics({
            "accuracy": accuracy, "f1_score": f1,
            "precision": precision, "recall": recall,
            "training_time_secs": training_time,
        })

        # TODO 7 ✓
        with tempfile.TemporaryDirectory() as tmpdir:
            cm_path = os.path.join(tmpdir, "confusion_matrix.png")
            save_confusion_matrix(y_test, y_pred, cm_path)
            mlflow.log_artifacts(tmpdir, artifact_path="plots")

        # TODO 8 ✓
        signature = infer_signature(X_train, model.predict(X_train))
        mlflow.sklearn.log_model(model, "model", signature=signature, input_example=X_train[:3])

        # TODO 9 ✓
        mlflow.set_tag("model_family", args.model)

        print(f"[{run_name}] accuracy={accuracy:.4f}  f1={f1:.4f}  time={training_time:.2f}s")


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True, choices=["random-forest", "logistic-regression", "svm"])
    p.add_argument("--n-estimators", type=int, default=100)
    p.add_argument("--max-depth", type=int, default=None)
    p.add_argument("--C", type=float, default=1.0)
    p.add_argument("--kernel", choices=["linear", "rbf", "poly"], default="rbf")
    return p.parse_args()


if __name__ == "__main__":
    run_experiment(parse_args())
