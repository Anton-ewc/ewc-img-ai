#!/bin/bash

# ==========================================
# FLUX.1 [schnell] + WebUI Forge Auto-Installer
# (Fixed for Ubuntu 24.04 / Noble)
# ==========================================

# Stop script on error
set -e

# Colors for formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Automated Installer (v2)...${NC}"

# 1. Check for Sudo/Root to install dependencies
if [ "$EUID" -ne 0 ]; then
  echo -e "${BLUE}Asking for sudo permissions to install dependencies...${NC}"
  sudo -v
fi

# 2. Add Python 3.10 Repository (Critical for Ubuntu 23.04/24.04+)
echo -e "${GREEN}[1/6] checking for Python 3.10 availability...${NC}"

# Install software-properties-common to allow adding PPAs
sudo apt update -y
sudo apt install -y software-properties-common

# Check if python3.10 is in the current repo, if not, add deadsnakes PPA
if ! apt-cache show python3.10 >/dev/null 2>&1; then
    echo -e "${BLUE}Python 3.10 not found in standard repo. Adding deadsnakes PPA...${NC}"
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update -y
fi

# 3. Install System Dependencies
echo -e "${GREEN}[2/6] Installing system dependencies (Python 3.10, Git, Libraries)...${NC}"
# Note: libglib2.0-0 might be auto-replaced by libglib2.0-0t64 on 24.04, which is fine.
sudo apt install -y wget git python3.10 python3.10-venv python3.10-dev python3-pip libgl1 libglib2.0-0 google-perftools

# 4. Clone WebUI Forge
INSTALL_DIR="stable-diffusion-webui-forge"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Directory '$INSTALL_DIR' already exists.${NC}"
    # We won't delete it automatically to avoid losing previous downloads, just skip if exists
    echo -e "${BLUE}Skipping clone step (assuming upgrade or repair)...${NC}"
else
    echo -e "${GREEN}[3/6] Cloning WebUI Forge Repository...${NC}"
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git $INSTALL_DIR
fi

cd $INSTALL_DIR

# 5. Configure Python 3.10 Path
echo -e "${GREEN}[4/6] Configuring environment to use Python 3.10...${NC}"
if [ -f "webui-user.sh" ]; then
    # Force python command to 3.10
    sed -i 's/#python_cmd="python3"/python_cmd="python3.10"/' webui-user.sh
    
    # Safety check: if the sed command didn't match (because file changed), append it
    if ! grep -q 'python_cmd="python3.10"' webui-user.sh; then
        echo 'python_cmd="python3.10"' >> webui-user.sh
    fi
else
    echo '#!/bin/bash' > webui-user.sh
    echo 'python_cmd="python3.10"' >> webui-user.sh
fi

# 6. Download FLUX.1 [schnell] Model
MODEL_DIR="models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
MODEL_FILE="flux1-schnell-fp8.safetensors"

echo -e "${GREEN}[5/6] Downloading FLUX.1 [schnell] model (approx. 11GB)...${NC}"
if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
    echo -e "${BLUE}Model already exists. Skipping download.${NC}"
else
    # Create dir if not exists (just in case)
    mkdir -p "$MODEL_DIR"
    wget -O "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL" --progress=bar:force
fi

# 7. Final Permissions
chmod +x webui.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "To start the generator:"
echo -e "1. ${BLUE}cd $INSTALL_DIR${NC}"
echo -e "2. ${BLUE}./webui.sh${NC}"
echo -e ""
echo -e "Open your browser at: http://127.0.0.1:7860"

# Optional: Run
read -p "Do you want to run it now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./webui.sh
fi