#!/bin/bash
# Start script for ACE-Step on RunPod with Jupyter Integration

# 1. Ensure models exist (Download if missing)
# Using /workspace/models if a persistent volume is attached, otherwise /app/models
MODEL_DIR="${PERSISTENT_VOLUME_ROOT:-/app}/checkpoints"
mkdir -p "$MODEL_DIR"

if [ -z "$(ls -A $MODEL_DIR 2>/dev/null)" ]; then
    echo "Models not found in $MODEL_DIR. Downloading from Hugging Face..."
    # Ensure HF_TOKEN is available as an environment variable in RunPod
    python3 -m huggingface_hub snapshot_download \
        --repo_id "ACE-Step/Ace-Step1.5" \
        --local_dir "$MODEL_DIR" \
        --token "$HF_TOKEN" \
        --ignore_patterns "acestep-v15-turbo/*"
else
    echo "Models already present in $MODEL_DIR. Skipping download."
fi

# 2. Set Paths
CONFIG_PATH="${ACESTEP_CONFIG_PATH:-$MODEL_DIR/acestep-v15-base}"
LM_MODEL_PATH="${ACESTEP_LM_MODEL_PATH:-$MODEL_DIR/acestep-5Hz-lm-1.7B}"

# 3. Start Jupyter Lab in background (Port 8888)
echo "Starting Jupyter Lab on port 8888..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --NotebookApp.allow_origin='*' > /app/jupyter.log 2>&1 &

# 4. Start Gradio UI in background (Port 7860)
echo "Starting Gradio UI..."
acestep --server-name 0.0.0.0 --port 7860 --init_service true \
    --config_path "$CONFIG_PATH" --lm_model_path "$LM_MODEL_PATH" \
    --backend pt 2>&1 | tee /app/gradio.log &

# 5. Start API server in background (Port 8000)
sleep 10
echo "Starting API server..."
acestep-api --host 0.0.0.0 --port 8000 2>&1 | tee /app/api.log &

echo "All services initiated."
# Keep container alive
sleep infinity
