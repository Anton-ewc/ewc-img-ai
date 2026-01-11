#!/bin/bash

# ==========================================
# FLUX.1 [schnell] + WebUI Forge Auto-Installer
# (Conda Edition - Works on ALL Ubuntu versions)
# ==========================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/stable-diffusion-webui-forge"
CONDA_DIR="$HOME/miniconda3"
MODEL_DIR="$INSTALL_DIR/models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/blob/main/flux1-schnell-fp8.safetensors?download=true"

echo -e "${BLUE}Starting Bulletproof Installer...${NC}"

# 1. Install System Basics (Git & Libraries only)
echo -e "${GREEN}[1/5] Installing basic system libraries...${NC}"
sudo apt update -y
sudo apt install -y wget git libgl1 libglib2.0-0 google-perftools

# 2. Install Miniconda (if not present)
# This gives us a private Python 3.10 without fighting Ubuntu 24.04
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${GREEN}[2/5] Installing Miniconda (Private Python Manager)...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
else
    echo -e "${BLUE}Miniconda already installed. Skipping.${NC}"
fi

# Activate Conda for this script session
source "$CONDA_DIR/bin/activate"

# 3. Create the Forge Environment (Python 3.10)
if { conda env list | grep -q 'forge-env'; }; then
    echo -e "${BLUE}Environment 'forge-env' already exists. Skipping creation.${NC}"
else
    echo -e "${GREEN}[3/5] Creating isolated Python 3.10 environment...${NC}"
    conda create -n forge-env python=3.10 -y
fi

# 4. Clone WebUI Forge
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}Forge directory exists. Skipping clone.${NC}"
else
    echo -e "${GREEN}[4/5] Cloning WebUI Forge...${NC}"
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$INSTALL_DIR"
fi

# 5. Download FLUX Model
echo -e "${GREEN}[5/5] Downloading FLUX.1 [schnell] Model (11GB)...${NC}"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ]; then
    echo -e "${BLUE}Model already exists. Skipping download.${NC}"
else
    # We use -O to ensure the filename is correct because the URL has query parameters
    wget -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force
fi

# 6. Create a "Run" Script
# This script ensures the correct environment is always loaded when you run it
echo -e "${GREEN}Creating launcher script 'run_forge.sh'...${NC}"
cat <<EOT > run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate"
conda activate forge-env
cd "$INSTALL_DIR"
./webui.sh
EOT

chmod +x run_forge.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "To start the generator, simply run:"
echo -e "${BLUE}./run_forge.sh${NC}"
echo -e ""
echo -e "Open your browser at: http://127.0.0.1:7860"

# Optional: Run Now
read -p "Do you want to run it now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./run_forge.sh
fi