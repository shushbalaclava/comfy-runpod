#!/bin/bash
COMFY=/opt/ComfyUI
BASE="https://raw.githubusercontent.com/shushbalaclava/comfy-runpod/main"

MODELS_URL="${MODELS_URL:-$BASE/models.txt}"
WORKFLOWS_URL="${WORKFLOWS_URL:-$BASE/workflow.json}"
NODES_URL="${NODES_URL:-$BASE/nodes.txt}"

python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'gpu available:', torch.cuda.is_available())"

# --- Lock torch so no custom node can change it ---
pip freeze | grep -iE '^(torch|torchvision|torchaudio)==' > /tmp/constraints.txt

# --- Custom nodes ---
curl -fsSL "$NODES_URL" -o /tmp/nodes.txt || { echo "nodes.txt download failed"; : > /tmp/nodes.txt; }
cd "$COMFY/custom_nodes"
while read -r repo; do
  [ -z "$repo" ] && continue
  [[ "$repo" == \#* ]] && continue
  name=$(basename "$repo" .git)
  [ -d "$name" ] || git clone --depth 1 "$repo" "$name" || continue
  [ -f "$name/requirements.txt" ] && pip install --no-cache-dir -r "$name/requirements.txt" -c /tmp/constraints.txt
  [ -f "$name/install.py" ] && (cd "$name" && python install.py)
done < /tmp/nodes.txt

# --- Workflow ---
mkdir -p "$COMFY/user/default/workflows"
curl -fsSL "$WORKFLOWS_URL" -o "$COMFY/user/default/workflows/workflow.json" \
  || echo "Workflow download failed"

# --- Model list ---
curl -fsSL "$MODELS_URL" -o /tmp/models.txt

# Start ComfyUI now so the UI is reachable while models download
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
  if [[ "$url" == *civitai.* && -n "$CIVITAI_TOKEN" ]]; then
    [[ "$url" == *\?* ]] && sep="&" || sep="?"
    dl="${url}${sep}token=${CIVITAI_TOKEN}"
  fi

  aria2c -x16 -s16 -c "${hdr[@]}" -d "$dest" -o "$file" "$dl"
done < /tmp/models.txt

echo "All models downloaded"
wait
