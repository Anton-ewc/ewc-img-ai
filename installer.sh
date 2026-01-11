#!/bin/bash

# ==========================================
# FLUX.1 [schnell] + WebUI Forge Auto-Installer
# (Fixed for Ubuntu 24.04 / Noble)
# ==========================================

# Stop on error
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Starting Automated Installer (v3 - Noble Fix)...${NC}"

# 1. Check for Sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${BLUE}Asking for sudo permissions...${NC}"
  sudo -v
fi

# 2. FORCE Add Python 3.10 Repository (Deadsnakes)
# Ubuntu 24.04 DOES NOT have python3.10 by default. We must add this PPA.
echo -e "${GREEN}[1/6] Setting up Python 3.10 repository...${NC}"
sudo apt update -y
sudo apt install -y software-properties-common

# We unconditionally add the PPA on 24.04 to ensure we get the real package, not a virtual reference.
echo -e "${BLUE}Adding Deadsnakes PPA (Required for Python 3.10 on Ubuntu 24.04)...${NC}"
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y

# 3. Install System Dependencies
echo -e "${GREEN}[2/6] Installing system dependencies...${NC}"
sudo apt install -y wget git python3.10 python3.10-venv python3.10-dev python3-pip libgl1 libglib2.0-0 google-perftools

# 4. Clone WebUI Forge
INSTALL_DIR="stable-diffusion-webui-forge"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}Directory exists. Skipping clone.${NC}"
else
    echo -e "${GREEN}[3/6] Cloning WebUI Forge...${NC}"
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git $INSTALL_DIR
fi

cd $INSTALL_DIR

# 5. Configure Python 3.10 Path
echo -e "${GREEN}[4/6] Configuring WebUI to use Python 3.10...${NC}"
# Create or Update webui-user.sh to force Python 3.10
if [ -f "webui-user.sh" ]; then
    sed -i 's/#python_cmd="python3"/python_cmd="python3.10"/' webui-user.sh
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

echo -e "${GREEN}[5/6] Downloading FLUX.1 [schnell] model (11GB)...${NC}"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
    echo -e "${BLUE}Model already exists. Skipping download.${NC}"
else
    wget -O "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL" --progress=bar:force
fi

# 7. Final Permissions
chmod +x webui.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "1. ${BLUE}cd $INSTALL_DIR${NC}"
echo -e "2. ${BLUE}./webui.sh${NC}"

read -p "Do you want to run it now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./webui.sh
fi