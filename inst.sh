#!/bin/bash

# ==========================================
# FLUX.1 + Forge "Direct Launch" Installer
# (Fixes: Path Logic Errors, Webui.sh bugs)
# ==========================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Paths ---
INSTALL_DIR="$HOME/forge"
CONDA_DIR="$HOME/miniconda3"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"

# --- Temp File Redirect ---
mkdir -p "$HOME/pip_tmp_cache"
export TMPDIR="$HOME/pip_tmp_cache"

echo -e "${BLUE}Starting Installer (v11 - Direct Launch)...${NC}"

# 1. System Dependencies
echo -e "${GREEN}[1/9] Installing Dependencies...${NC}"
git config --global http.postBuffer 524288000
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools curl

# 2. Miniconda & Environment
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${GREEN}[2/9] Installing Miniconda...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi

source "$CONDA_DIR/bin/activate"

if { conda env list | grep -q 'forge-env'; }; then
    echo -e "${BLUE}Environment exists. Skipping creation.${NC}"
else
    echo -e "${GREEN}[3/9] Creating Environment...${NC}"
    conda create -n forge-env python=3.10 -y
fi
conda activate forge-env

# 3. Hardware / PyTorch
echo -e "${GREEN}[4/9] Installing PyTorch...${NC}"
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA drivers missing.${NC}"
    exit 1
fi
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
pip cache purge
pip uninstall -y torch torchvision torchaudio xformers

if [[ "$GPU_NAME" == *"RTX 50"* ]] || [[ "$GPU_NAME" == *"Blackwell"* ]]; then
    echo -e "${BLUE}>> RTX 50-Series detected. Installing Nightly PyTorch...${NC}"
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126 --no-cache-dir
else
    echo -e "${BLUE}>> Standard GPU detected. Installing Stable PyTorch...${NC}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 --no-cache-dir
fi

# 4. Install Forge Source Code
echo -e "${GREEN}[5/9] Installing WebUI Forge Source...${NC}"
if [ -d "$INSTALL_DIR" ]; then rm -rf "$INSTALL_DIR"; fi
if [ -d "stable-diffusion-webui-forge-main" ]; then rm -rf "stable-diffusion-webui-forge-main"; fi

wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
unzip -q forge.zip

# Find extraction folder dynamically
EXTRACTED_DIR=$(ls -d stable-diffusion-webui-forge-* | head -n 1)
mv "$EXTRACTED_DIR" "$INSTALL_DIR"
rm forge.zip

# 5. Download Model
echo -e "${GREEN}[6/9] Downloading FLUX Model...${NC}"
MODEL_DIR="$INSTALL_DIR/models/Stable-diffusion"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ] && [ $(stat -c%s "$MODEL_DIR/flux1-schnell-fp8.safetensors") -gt 10000000000 ]; then
     echo -e "${BLUE}Model seems valid. Skipping.${NC}"
else
     wget -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force
fi

# 6. Repository Fix (Manual Planting)
echo -e "${GREEN}[7/9] Planting 'repositories'...${NC}"
REPO_DIR="$INSTALL_DIR/repositories"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# Download CompVis source
wget -O repo.zip https://github.com/CompVis/stable-diffusion/archive/refs/heads/main.zip
unzip -q repo.zip
mv stable-diffusion-main stable-diffusion-stability-ai
rm repo.zip

# 7. Code Patching (Disable Git)
echo -e "${GREEN}[8/9] Patching Source Code...${NC}"
LAUNCH_UTILS=$(find "$INSTALL_DIR" -name "launch_utils.py" | head -n 1)

if [ -f "$LAUNCH_UTILS" ]; then
    echo -e "${BLUE}Patching: $LAUNCH_UTILS${NC}"
    # Disable git clones
    sed -i 's/git_clone(stable_diffusion_repo/# git_clone(stable_diffusion_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(taming_transformers_repo/# git_clone(taming_transformers_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(k_diffusion_repo/# git_clone(k_diffusion_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(codeformer_repo/# git_clone(codeformer_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(blip_repo/# git_clone(blip_repo/' "$LAUNCH_UTILS"
else
    echo -e "${RED}Warning: launch_utils.py not found.${NC}"
fi

# 8. Create Direct Launcher (Bypasses webui.sh)
echo -e "${GREEN}[9/9] Creating Direct Launcher...${NC}"
cd "$HOME"

cat <<EOT > run_forge.sh
#!/bin/bash
# 1. Initialize Conda
source "$CONDA_DIR/bin/activate"
conda activate forge-env

# 2. Move to Install Directory
cd "$INSTALL_DIR"

# 3. Set Root Permissions (Just in case logic checks for it)
export can_run_as_root=1

# 4. Run Launch.py DIRECTLY (Bypassing webui.sh wrapper)
# We add --listen so you can access it remotely
python launch.py --listen --enable-insecure-extension-access
EOT

chmod +x run_forge.sh

echo -e "${GREEN}SUCCESS! Run with: ./run_forge.sh${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Run this command to start:"

echo -e "${GREEN} URL: http://<YOUR_IP>:7860"