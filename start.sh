#!/bin/bash
COMFY=/opt/ComfyUI

MODELS_URL="${MODELS_URL:-https://raw.githubusercontent.com/shushbalaclava/comfy-runpod/main/models.txt}"
WORKFLOWS_URL="${WORKFLOWS_URL:-https://raw.githubusercontent.com/shushbalaclava/comfy-runpod/main/workflow.json}"

# Print versions in the logs
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'gpu available:', torch.cuda.is_available())"

# --- Workflow ---
mkdir -p "$COMFY/user/default/workflows"
curl -fsSL "$WORKFLOWS_URL" -o "$COMFY/user/default/workflows/workflow.json" \
  || echo "Workflow download failed"

# --- Model list ---
curl -fsSL "$MODELS_URL" -o /tmp/models.txt

# Start ComfyUI right away so the UI is reachable while models download
cd "$COMFY" && python main.py --listen 0.0.0.0 --port 8188 &

# --- Models: url|folder|optional filename ---
while IFS='|' read -r url dir name; do
  [ -z "$url" ] && continue
  [[ "$url" == \#* ]] && continue
  dest="$COMFY/models/$dir"; mkdir -p "$dest"
  file="${name:-$(basename "${url%%\?*}")}"
  [ -f "$dest/$file" ] && continue

  hdr=()
  dl="$url"
  [[ "$url" == *huggingface.co* && -n "$HF_TOKEN" ]] && hdr=(--header="Authorization: Bearer $HF_TOKEN")
  if [[ "$url" == *civitai.com* && -n "$CIVITAI_TOKEN" ]]; then
    [[ "$url" == *\?* ]] && sep="&" || sep="?"
    dl="${url}${sep}token=${CIVITAI_TOKEN}"
  fi

  aria2c -x16 -s16 -c "${hdr[@]}" -d "$dest" -o "$file" "$dl"
done < /tmp/models.txt

echo "All models downloaded"
wait
