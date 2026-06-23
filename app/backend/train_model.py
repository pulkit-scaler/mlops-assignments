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
