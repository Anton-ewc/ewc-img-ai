#!/bin/bash

# ==========================================
# FLUX.1 + Forge "Final Fix" Installer
# (Fixes: Folder Names, Missing Launch.py, Git Loops)
# ==========================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Paths ---
# We install to a generic name to avoid path confusion
INSTALL_DIR="$HOME/forge"
CONDA_DIR="$HOME/miniconda3"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"

# --- CRITICAL FIX: Redirect Temp Files ---
mkdir -p "$HOME/pip_tmp_cache"
export TMPDIR="$HOME/pip_tmp_cache"

echo -e "${BLUE}Starting Installer (v10 - Robust Edition)...${NC}"

# 1. System Prep
echo -e "${GREEN}[1/11] Installing Dependencies...${NC}"
git config --global http.postBuffer 524288000
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools curl

# 2. Miniconda
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${GREEN}[2/11] Installing Miniconda...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi

source "$CONDA_DIR/bin/activate"

if { conda env list | grep -q 'forge-env'; }; then
    echo -e "${BLUE}Environment exists. Skipping creation.${NC}"
else
    echo -e "${GREEN}[3/11] Creating Environment...${NC}"
    conda create -n forge-env python=3.10 -y
fi

conda activate forge-env

# 3. Hardware Detection
echo -e "${GREEN}[4/11] Detecting GPU...${NC}"
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA drivers missing.${NC}"
    exit 1
fi
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
echo -e "${YELLOW}Detected GPU: $GPU_NAME${NC}"

# Clean old torch
pip cache purge
pip uninstall -y torch torchvision torchaudio xformers

if [[ "$GPU_NAME" == *"RTX 50"* ]] || [[ "$GPU_NAME" == *"Blackwell"* ]]; then
    echo -e "${BLUE}>> Installing Nightly PyTorch (RTX 50-Series)...${NC}"
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126 --no-cache-dir
else
    echo -e "${BLUE}>> Installing Stable PyTorch (Standard GPU)...${NC}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 --no-cache-dir
fi

# 4. Install Forge (Robust Method)
echo -e "${GREEN}[5/11] Installing WebUI Forge...${NC}"
# Delete old folder to ensure clean install
if [ -d "$INSTALL_DIR" ]; then rm -rf "$INSTALL_DIR"; fi
if [ -d "stable-diffusion-webui-forge-main" ]; then rm -rf "stable-diffusion-webui-forge-main"; fi

# Download ZIP
echo -e "${BLUE}Downloading Source Code...${NC}"
wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
unzip -q forge.zip

# DYNAMIC FOLDER DETECTION: Find what the zip actually extracted
EXTRACTED_DIR=$(ls -d stable-diffusion-webui-forge-* | head -n 1)
echo -e "${BLUE}Found extracted folder: $EXTRACTED_DIR${NC}"

# Rename to our install dir
mv "$EXTRACTED_DIR" "$INSTALL_DIR"
rm forge.zip

# Verify Launch.py exists
if [ ! -f "$INSTALL_DIR/launch.py" ]; then
    echo -e "${RED}CRITICAL ERROR: launch.py not found in $INSTALL_DIR${NC}"
    echo -e "${RED}Installation failed. Please check the logs.${NC}"
    exit 1
fi

# 5. Download Model
echo -e "${GREEN}[6/11] Downloading FLUX Model...${NC}"
MODEL_DIR="$INSTALL_DIR/models/Stable-diffusion"
mkdir -p "$MODEL_DIR"

if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ] && [ $(stat -c%s "$MODEL_DIR/flux1-schnell-fp8.safetensors") -gt 10000000000 ]; then
     echo -e "${BLUE}Model seems valid. Skipping.${NC}"
else
     wget -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force
fi

# 6. FIX: Create Repositories (Double Placement Strategy)
echo -e "${GREEN}[7/11] Pre-installing 'stable-diffusion' Repo...${NC}"
# We will put the repo in BOTH possible locations to prevent errors
REPO_PATH_1="$INSTALL_DIR/repositories"
REPO_PATH_2="$INSTALL_DIR/stable-diffusion-webui/repositories"

# Download Repo ZIP once
wget -O repo.zip https://github.com/CompVis/stable-diffusion/archive/refs/heads/main.zip
unzip -q repo.zip
mv stable-diffusion-main stable-diffusion-stability-ai

# Place in Root Repositories
mkdir -p "$REPO_PATH_1"
cp -r stable-diffusion-stability-ai "$REPO_PATH_1/"

# Place in Nested Repositories (just in case)
mkdir -p "$REPO_PATH_2"
cp -r stable-diffusion-stability-ai "$REPO_PATH_2/"

# Cleanup source
rm -rf stable-diffusion-stability-ai repo.zip

echo -e "${BLUE}Repository planted in valid locations.${NC}"

# 7. CRITICAL FIX: Patch Python Code (Disable Git)
echo -e "${GREEN}[8/11] Patching Installer to SKIP Git Clone...${NC}"

# Find launch_utils.py
LAUNCH_UTILS=$(find "$INSTALL_DIR" -name "launch_utils.py" | head -n 1)

if [ -f "$LAUNCH_UTILS" ]; then
    echo -e "${BLUE}Patching: $LAUNCH_UTILS${NC}"
    # Comment out git_clone commands
    sed -i 's/git_clone(stable_diffusion_repo/# git_clone(stable_diffusion_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(taming_transformers_repo/# git_clone(taming_transformers_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(k_diffusion_repo/# git_clone(k_diffusion_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(codeformer_repo/# git_clone(codeformer_repo/' "$LAUNCH_UTILS"
    sed -i 's/git_clone(blip_repo/# git_clone(blip_repo/' "$LAUNCH_UTILS"
else
    echo -e "${RED}Warning: launch_utils.py not found.${NC}"
fi

# 8. Patching System
echo -e "${GREEN}[9/11] Applying Root/Network Patches...${NC}"
cd "$INSTALL_DIR"
sed -i 's/can_run_as_root=0/can_run_as_root=1/' webui.sh

if [ ! -f "webui-user.sh" ]; then echo '#!/bin/bash' > webui-user.sh; fi
# Always overwrite args to be safe
sed -i '/export COMMANDLINE_ARGS/d' webui-user.sh
echo 'export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"' >> webui-user.sh

# 9. Cleanup
echo -e "${GREEN}[10/11] Cleaning Temp Files...${NC}"
rm -rf "$HOME/pip_tmp_cache"

# 10. Launcher
echo -e "${GREEN}[11/11] Creating Launcher...${NC}"
cd "$HOME"
cat <<EOT > run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate"
conda activate forge-env
cd "$INSTALL_DIR"
export python_cmd="python"
./webui.sh
EOT
chmod +x run_forge.sh

echo -e "${GREEN}SUCCESS! Run with: ./run_forge.sh${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Run this command to start:"

echo -e "${GREEN} URL: http://<YOUR_IP>:7860"