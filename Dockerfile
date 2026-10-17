FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

RUN apt-get update && apt-get install -y aria2 git curl && rm -rf /var/lib/apt/lists/*

# Force PyTorch built for CUDA 12.8 (2.7 or newer)
RUN pip install --no-cache-dir "torch>=2.7" torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

WORKDIR /opt
RUN git clone https://github.com/comfyanonymous/ComfyUI.git \
 && pip install --no-cache-dir -r ComfyUI/requirements.txt

# Optional: custom nodes your workflow needs go HERE (before the check), e.g.:
# RUN cd ComfyUI/custom_nodes \
#  && git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
#  && pip install --no-cache-dir -r ComfyUI-Manager/requirements.txt

# Fail the build if the versions are wrong
RUN python -c "import torch; v=tuple(map(int,torch.__version__.split('+')[0].split('.')[:2])); \
assert v>=(2,7), torch.__version__; \
assert torch.version.cuda=='12.8', torch.version.cuda; \
print('OK', torch.__version__, torch.version.cuda)"

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188
CMD ["/start.sh"]
