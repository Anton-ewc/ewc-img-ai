#!/bin/bash

# ==========================================
# FLUX.1 + Forge "Path Finder" Installer
# (Fixes: Wrong Folder Path, Git Loop, Root)
# ==========================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Paths ---
INSTALL_DIR="$HOME/stable-diffusion-webui-forge"
CONDA_DIR="$HOME/miniconda3"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"

# --- CRITICAL FIX: Redirect Temp Files ---
mkdir -p "$HOME/pip_tmp_cache"
export TMPDIR="$HOME/pip_tmp_cache"

echo -e "${BLUE}Starting Installer (v9 - Path Fix Edition)...${NC}"

# 1. System Prep
echo -e "${GREEN}[1/10] Installing Dependencies...${NC}"
git config --global http.postBuffer 524288000
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools curl

# 2. Miniconda
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${GREEN}[2/10] Installing Miniconda...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi

source "$CONDA_DIR/bin/activate"

if { conda env list | grep -q 'forge-env'; }; then
    echo -e "${BLUE}Environment exists. Skipping creation.${NC}"
else
    echo -e "${GREEN}[3/10] Creating Environment...${NC}"
    conda create -n forge-env python=3.10 -y
fi

conda activate forge-env

# 3. Hardware Detection & Installation
echo -e "${GREEN}[4/10] Detecting GPU...${NC}"
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA drivers missing.${NC}"
    exit 1
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
echo -e "${YELLOW}Detected GPU: $GPU_NAME${NC}"

pip cache purge
pip uninstall -y torch torchvision torchaudio xformers

if [[ "$GPU_NAME" == *"RTX 50"* ]] || [[ "$GPU_NAME" == *"Blackwell"* ]]; then
    echo -e "${BLUE}>> Installing Nightly PyTorch (RTX 50-Series)...${NC}"
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126 --no-cache-dir
else
    echo -e "${BLUE}>> Installing Stable PyTorch (Standard GPU)...${NC}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 --no-cache-dir
fi

# 4. Install Forge
echo -e "${GREEN}[5/10] Installing WebUI Forge...${NC}"
if [ -d "$INSTALL_DIR" ]; then rm -rf "$INSTALL_DIR"; fi

wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
unzip -q forge.zip
mv stable-diffusion-webui-forge-main "$INSTALL_DIR"
rm forge.zip

# 5. Download Model
echo -e "${GREEN}[6/10] Downloading FLUX Model...${NC}"
# Correct path for model is inside the inner webui folder usually, but we check both
MODEL_DIR="$INSTALL_DIR/models/Stable-diffusion"
mkdir -p "$MODEL_DIR"

if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ] && [ $(stat -c%s "$MODEL_DIR/flux1-schnell-fp8.safetensors") -gt 10000000000 ]; then
     echo -e "${BLUE}Model seems valid. Skipping.${NC}"
else
     wget -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force
fi

# 6. FIX: FIND THE CORRECT REPOSITORIES FOLDER AUTOMATICALLY
echo -e "${GREEN}[7/10] Locating 'repositories' folder...${NC}"

# We use 'find' to locate the folder because it might be nested
REPO_PARENT=$(find "$INSTALL_DIR" -type d -name "repositories" | head -n 1)

if [ -z "$REPO_PARENT" ]; then
    # If not found, create it where the logs suggested it should be
    echo -e "${YELLOW}Repositories folder not found. Creating it manually...${NC}"
    REPO_PARENT="$INSTALL_DIR/stable-diffusion-webui/repositories"
    mkdir -p "$REPO_PARENT"
fi

echo -e "${BLUE}Found repositories folder at: $REPO_PARENT${NC}"
cd "$REPO_PARENT"

# Cleanup
rm -rf stable-diffusion-stability-ai repo.zip

echo -e "${BLUE}Manually Downloading Repo...${NC}"
wget -O repo.zip https://github.com/CompVis/stable-diffusion/archive/refs/heads/main.zip
unzip -q repo.zip
mv stable-diffusion-main stable-diffusion-stability-ai
rm repo.zip

# 7. CRITICAL FIX: Patch the Python Code
echo -e "${GREEN}[8/10] Patching Installer to SKIP Git Clone...${NC}"

# Find launch_utils.py wherever it is hiding
LAUNCH_UTILS=$(find "$INSTALL_DIR" -name "launch_utils.py" | head -n 1)

if [ -f "$LAUNCH_UTILS" ]; then
    echo -e "${BLUE}Patching file: $LAUNCH_UTILS${NC}"
    # Comment out the git_clone command for stability-ai
    sed -i 's/git_clone(stable_diffusion_repo/# git_clone(stable_diffusion_repo/' "$LAUNCH_UTILS"
    echo -e "${BLUE}Patch applied!${NC}"
else
    echo -e "${RED}WARNING: Could not find launch_utils.py to patch.${NC}"
fi

# 8. Patching System
echo -e "${GREEN}[9/10] Applying System Patches...${NC}"
cd "$INSTALL_DIR"
sed -i 's/can_run_as_root=0/can_run_as_root=1/' webui.sh

if [ ! -f "webui-user.sh" ]; then echo '#!/bin/bash' > webui-user.sh; fi
if grep -q "COMMANDLINE_ARGS" webui-user.sh; then
    sed -i 's/export COMMANDLINE_ARGS=.*/export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"/' webui-user.sh
else
    echo 'export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"' >> webui-user.sh
fi

# 9. Cleanup
echo -e "${BLUE}Cleaning up...${NC}"
rm -rf "$HOME/pip_tmp_cache"

# 10. Launcher
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
echo -e "${BLUE}./run_forge.sh${NC}"
echo -e "${GREEN} URL: http://<YOUR_IP>:7860"