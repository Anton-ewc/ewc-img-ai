#!/bin/bash

# ==========================================
# GPU & PyTorch Fixer for WebUI Forge
# ==========================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
CONDA_DIR="$HOME/miniconda3"

echo -e "${BLUE}Starting GPU Diagnostics...${NC}"

# 1. Check GPU Model
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: 'nvidia-smi' not found. Do you have an NVIDIA GPU installed?${NC}"
    exit 1
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
echo -e "${GREEN}Detected GPU: $GPU_NAME${NC}"

# 2. Activate Environment
echo -e "${BLUE}Activating Forge Environment...${NC}"
source "$CONDA_DIR/bin/activate"
conda activate forge-env

# 3. Force Reinstall PyTorch (CUDA 12.1 Build)
# This is the most compatible modern build for Flux
echo -e "${GREEN}Force-reinstalling PyTorch (CUDA 12.1)...${NC}"
pip uninstall -y torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 4. Check if GPU is too old
# Flux generally requires Pascal (10-series) or newer.
# If user has K80, M40, M60, this will likely fail again.
if [[ "$GPU_NAME" == *"K80"* ]] || [[ "$GPU_NAME" == *"M60"* ]] || [[ "$GPU_NAME" == *"M40"* ]]; then
    echo -e "${RED}WARNING: Your GPU ($GPU_NAME) is very old (Compute Capability < 6.0).${NC}"
    echo -e "${RED}Modern AI models like FLUX require PyTorch 2.0+, which does not support this card.${NC}"
    echo -e "${RED}You may not be able to run FLUX on this hardware.${NC}"
else
    echo -e "${GREEN}PyTorch reinstalled. Trying to run Forge...${NC}"
    
    # Run the launcher we made earlier
    cd "$HOME/stable-diffusion-webui-forge"
    ./webui.sh
fi