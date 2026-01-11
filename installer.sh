#!/bin/bash

# ==========================================
# FLUX.1 [schnell] + WebUI Forge Auto-Installer
# (v6: HTTP/1.1 Force + ZIP Fallback Edition)
# ==========================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Paths
INSTALL_DIR="$HOME/stable-diffusion-webui-forge"
CONDA_DIR="$HOME/miniconda3"
MODEL_DIR="$INSTALL_DIR/models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"

echo -e "${BLUE}Starting Final Fix Installer...${NC}"

# 1. CRITICAL GIT FIXES (Solves "curl 92" and "RPC failed")
echo -e "${GREEN}[1/7] Applying Git Network Fixes (Force HTTP/1.1)...${NC}"
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# 2. Install Dependencies (Added 'unzip' for backup method)
echo -e "${GREEN}[2/7] Installing system tools...${NC}"
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools

# 3. Install Miniconda
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${GREEN}[3/7] Installing Miniconda...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
else
    echo -e "${BLUE}Miniconda already installed.${NC}"
fi

source "$CONDA_DIR/bin/activate"

# 4. Create Environment
if { conda env list | grep -q 'forge-env'; }; then
    echo -e "${BLUE}Environment 'forge-env' exists. Skipping.${NC}"
else
    echo -e "${GREEN}[4/7] Creating Python 3.10 environment...${NC}"
    conda create -n forge-env python=3.10 -y
fi

# 5. Download WebUI Forge (The "Fail-Safe" Method)
echo -e "${GREEN}[5/7] Downloading WebUI Forge...${NC}"

# Remove previous broken attempts
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

# Attempt 1: Git Clone (Optimized)
if git clone --depth 1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$INSTALL_DIR"; then
    echo -e "${BLUE}Git clone successful.${NC}"
else
    echo -e "${RED}Git clone failed again. Switching to ZIP download method...${NC}"
    
    # Attempt 2: ZIP Download (Bypasses Git Protocol completely)
    wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
    unzip forge.zip
    mv stable-diffusion-webui-forge-main "$INSTALL_DIR"
    rm forge.zip
    echo -e "${BLUE}ZIP installation successful.${NC}"
fi

# 6. Download FLUX Model
echo -e "${GREEN}[6/7] Downloading FLUX.1 [schnell] Model...${NC}"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ]; then
    echo -e "${BLUE}Model exists.${NC}"
else
    # Retry loop for model download
    wget -c -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force --tries=5
fi

# 7. Create Launcher
echo -e "${GREEN}[7/7] Creating launcher...${NC}"
cat <<EOT > run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate"
conda activate forge-env
cd "$INSTALL_DIR"
# Force Git updates to use HTTP 1.1 inside the app too
git config --global http.version HTTP/1.1
./webui.sh
EOT

chmod +x run_forge.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Run this command to start:"
echo -e "${BLUE}./run_forge.sh${NC}"