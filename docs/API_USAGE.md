# ACE-Step 1.5 API Usage Guide

This guide covers how to use the ACE-Step API for music generation, including practical examples and troubleshooting tips.

## Base URL

When running locally or via Docker:
```
http://localhost:8000
```

For RunPod deployments:
```
https://<POD_ID>-8000.proxy.runpod.net
```

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/v1/models` | GET | List available models |
| `/release_task` | POST | Create music generation task |
| `/query_result` | POST | Query task results |
| `/create_random_sample` | POST | Generate random music parameters via LLM |
| `/format_input` | POST | Format and enhance lyrics/caption via LLM |
| `/v1/audio` | GET | Download generated audio file |

## Quick Start Example

### 1. Check API Health

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "data": {"status": "ok", "service": "ACE-Step API", "version": "1.0"},
  "code": 200,
  "error": null
}
```

### 2. Generate Music

Submit a generation task with a caption (style description) and lyrics:

```bash
curl -X POST http://localhost:8000/release_task \
  -H "Content-Type: application/json" \
  -d '{
    "caption": "Warm acoustic folk song with gentle fingerpicked guitar, soft piano, and a cozy nostalgic atmosphere",
    "lyrics": "[Verse 1]\nLines of code like poetry\nPatterns dancing endlessly\n\n[Chorus]\nIn the logic we find grace\nEvery problem has its place",
    "duration": 90
  }'
```

Response:
```json
{
  "data": {
    "task_id": "ea782b05-87d3-428f-a269-27a7bea32c94",
    "status": "queued",
    "queue_position": 1
  },
  "code": 200
}
```

### 3. Query Task Result

Poll for the result using the task ID:

```bash
curl -X POST http://localhost:8000/query_result \
  -H "Content-Type: application/json" \
  -d '{"task_ids": ["ea782b05-87d3-428f-a269-27a7bea32c94"]}'
```

**Note:** Results may return empty (`"data": []`) while the task is still processing. Keep polling until you get results or check the server logs for completion.

### 4. Download Generated Audio

Once generation completes, audio files are saved to `/app/outputs/api_audio/`. Download using the **full absolute path**:

```bash
curl -o ./song.mp3 "http://localhost:8000/v1/audio?path=/app/outputs/api_audio/<filename>.mp3"
```

**Important:** The `path` parameter requires the full absolute path on the server, not just the filename.

Example:
```bash
curl -o song.mp3 "http://localhost:8000/v1/audio?path=/app/outputs/api_audio/e0a7dddd-9a3a-b5e0-c98b-b07bd36e2e2f.mp3"
```

## Request Parameters

### `/release_task` Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `caption` | string | Yes | Music style description (genre, instruments, mood) |
| `lyrics` | string | No | Song lyrics with structure tags like `[Verse]`, `[Chorus]` |
| `duration` | int | No | Duration in seconds (default varies by GPU tier) |
| `batch_size` | int | No | Number of variations to generate (default: 2) |

### Lyrics Format

Use structure tags to organize your lyrics:
```
[Verse 1]
First verse lyrics here
More lines...

[Chorus]
Catchy chorus lyrics
Repeat section...

[Verse 2]
Second verse lyrics

[Bridge]
Bridge section

[Outro]
Ending lyrics
```

## LLM-Powered Features

### Generate Random Sample Parameters

Let the LLM create random music parameters for you:

```bash
curl -X POST http://localhost:8000/create_random_sample \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Format/Enhance Lyrics

Use the LLM to improve or format your lyrics:

```bash
curl -X POST http://localhost:8000/format_input \
  -H "Content-Type: application/json" \
  -d '{
    "caption": "rock song",
    "lyrics": "some rough lyrics here"
  }'
```

## Troubleshooting

### Issue: Empty query results

**Symptom:** `/query_result` returns `{"data": []}` even after waiting.

**Cause:** Task is still processing, or the result was already retrieved (results may be single-use).

**Solution:** 
- Check server logs for generation progress
- Monitor for "Saved audio to..." log messages
- Results typically take 30-120 seconds depending on duration and GPU

### Issue: Audio file not found

**Symptom:** `/v1/audio` returns `{"detail": "Audio file not found: ..."}`

**Cause:** The `path` parameter format is incorrect.

**Solution:** Use the **full absolute path** including `/app/outputs/api_audio/`:
```bash
# Wrong - relative path
curl "http://localhost:8000/v1/audio?path=e0a7dddd.mp3"

# Wrong - partial path  
curl "http://localhost:8000/v1/audio?path=api_audio/e0a7dddd.mp3"

# Correct - full absolute path
curl "http://localhost:8000/v1/audio?path=/app/outputs/api_audio/e0a7dddd.mp3"
```

### Issue: Model checkpoint not found

**Symptom:** Server fails to start with error about missing model files in `/opt/venv/lib/python3.11/site-packages/checkpoints/`

**Cause:** ACE-Step looks for checkpoints relative to its installation directory. When installed in a virtualenv, it looks in the wrong location.

**Solution:** This was fixed by installing ACE-Step directly into `/app` instead of using a virtualenv. The Dockerfile now:
1. Clones ACE-Step into `/app`
2. Installs with `uv pip install --system`
3. Copies models to `/app/checkpoints`

This ensures `./checkpoints` resolves to `/app/checkpoints` where the models are baked in.

### Issue: VLC cannot play downloaded MP3

**Symptom:** VLC shows "cannot open file" errors even though the file exists.

**Cause:** This can be a permissions issue or VLC path handling quirk.

**Solution:** 
1. Verify the file is valid: `ffprobe ./song.mp3`
2. Copy to home directory: `cp ./song.mp3 ~/song.mp3`
3. Use alternative player: `mpv ./song.mp3` or `ffplay ./song.mp3`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ACESTEP_CONFIG_PATH` | `/app/checkpoints/acestep-v15-base` | Path to DiT model |
| `ACESTEP_LM_MODEL_PATH` | `/app/checkpoints/acestep-5Hz-lm-1.7B` | Path to LM model |
| `ACESTEP_OUTPUT_DIR` | `/app/outputs` | Output directory for generated audio |
| `ACESTEP_DEVICE` | `cuda` | Device (cuda, cpu, mps) |
| `ACESTEP_LM_BACKEND` | `pt` | LLM backend (vllm, pt) |
| `ACESTEP_API_HOST` | `0.0.0.0` | Server host |
| `ACESTEP_API_PORT` | `8000` | Server port |

## Complete Workflow Example

```bash
#!/bin/bash
API_URL="http://localhost:8000"

# 1. Submit generation task
RESPONSE=$(curl -s -X POST "$API_URL/release_task" \
  -H "Content-Type: application/json" \
  -d '{
    "caption": "Upbeat electronic dance music with synthesizers and driving beat",
    "lyrics": "[Drop]\nFeel the rhythm take control\nLet the music free your soul",
    "duration": 60
  }')

TASK_ID=$(echo $RESPONSE | jq -r '.data.task_id')
echo "Task submitted: $TASK_ID"

# 2. Poll for completion (check logs for actual file paths)
echo "Waiting for generation..."
sleep 60

# 3. Query result
curl -s -X POST "$API_URL/query_result" \
  -H "Content-Type: application/json" \
  -d "{\"task_ids\": [\"$TASK_ID\"]}" | jq

# 4. Download audio (get filename from server logs or query result)
# curl -o output.mp3 "$API_URL/v1/audio?path=/app/outputs/api_audio/<filename>.mp3"
```

## GPU Requirements

| GPU VRAM | Max Duration | Recommended LM Model |
|----------|--------------|---------------------|
| 8GB | 120s | acestep-5Hz-lm-0.6B |
| 16GB | 300s | acestep-5Hz-lm-1.7B |
| 24GB+ | 600s | acestep-5Hz-lm-4B |

## Links

- [ACE-Step GitHub](https://github.com/ace-step/ACE-Step-1.5)
- [Official API Documentation](https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/API.md)
- [Docker Image Source](https://github.com/ValyrianTech/ace-step-1.5)
