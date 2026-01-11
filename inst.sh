#!/bin/bash

# ==========================================
# FLUX.1 + Forge "Perfect" Installer
# (Fixes: Space, Nightly GPU, Missing Repo, Root)
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
MODEL_DIR="$INSTALL_DIR/models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"

# --- CRITICAL FIX: Redirect Temp Files ---
# Forces pip to use Home folder (prevents "No space left on device")
mkdir -p "$HOME/pip_tmp_cache"
export TMPDIR="$HOME/pip_tmp_cache"
echo -e "${BLUE}Redirecting temporary files to: $TMPDIR${NC}"

echo -e "${BLUE}Starting Installer...${NC}"

# 1. System Prep
echo -e "${GREEN}[1/9] Installing Dependencies...${NC}"
git config --global http.postBuffer 524288000
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools

# 2. Miniconda
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

# 3. Hardware Detection & Installation
echo -e "${GREEN}[4/9] Detecting GPU...${NC}"
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA drivers missing.${NC}"
    exit 1
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
echo -e "${YELLOW}Detected GPU: $GPU_NAME${NC}"

# Clean previous failed attempts
pip cache purge
pip uninstall -y torch torchvision torchaudio xformers

if [[ "$GPU_NAME" == *"RTX 50"* ]] || [[ "$GPU_NAME" == *"Blackwell"* ]]; then
    echo -e "${BLUE}>> Installing Nightly PyTorch (RTX 50-Series)...${NC}"
    # --no-cache-dir prevents saving the 2GB file twice, saving space
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126 --no-cache-dir
else
    echo -e "${BLUE}>> Installing Stable PyTorch (Standard GPU)...${NC}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 --no-cache-dir
fi

# 4. Install Forge
echo -e "${GREEN}[5/9] Installing WebUI Forge...${NC}"
if [ -d "$INSTALL_DIR" ]; then rm -rf "$INSTALL_DIR"; fi

# Use ZIP method to be safer against network drops
wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
unzip -q forge.zip
mv stable-diffusion-webui-forge-main "$INSTALL_DIR"
rm forge.zip

# 5. Download Model
echo -e "${GREEN}[6/9] Downloading FLUX Model...${NC}"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ] && [ $(stat -c%s "$MODEL_DIR/flux1-schnell-fp8.safetensors") -gt 10000000000 ]; then
     echo -e "${BLUE}Model seems valid. Skipping.${NC}"
else
     wget -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force
fi

# 6. FIX: Manually Clone Missing Repository
# This prevents the "Repository Not Found" error you saw earlier
echo -e "${GREEN}[7/9] Fixing Broken Repositories...${NC}"
mkdir -p "$INSTALL_DIR/repositories"
cd "$INSTALL_DIR/repositories"
# Clone the stability-ai repo manually using a reliable mirror
if [ ! -d "stable-diffusion-stability-ai" ]; then
    echo -e "${BLUE}Cloning stable-diffusion-stability-ai manually...${NC}"
    git clone https://github.com/AUTOMATIC1111/stablediffusion.git stable-diffusion-stability-ai
fi

# 7. Patching (Root & Remote Access)
echo -e "${GREEN}[8/9] Applying System Patches...${NC}"
cd "$INSTALL_DIR"

# Patch 1: Disable Root Check (Method A: sed replace)
sed -i 's/if \[ $(id -u) -eq 0 \]/if [ false ]/' webui.sh
# Patch 2: Disable Root Check (Method B: variable set)
sed -i 's/can_run_as_root=0/can_run_as_root=1/' webui.sh

# Patch 3: Enable Remote Access (Listen)
if [ ! -f "webui-user.sh" ]; then echo '#!/bin/bash' > webui-user.sh; fi
# Ensure args are set correctly
if grep -q "COMMANDLINE_ARGS" webui-user.sh; then
    sed -i 's/export COMMANDLINE_ARGS=.*/export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"/' webui-user.sh
else
    echo 'export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"' >> webui-user.sh
fi

# 8. Cleanup
echo -e "${BLUE}Cleaning up...${NC}"
rm -rf "$HOME/pip_tmp_cache"

# 9. Launcher
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