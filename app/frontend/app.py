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
