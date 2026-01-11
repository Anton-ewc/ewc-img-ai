#!/bin/bash

# ==========================================
# FLUX.1 [schnell] + WebUI Forge Auto-Installer
# ==========================================

# Stop script on error
set -e

# Colors for formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Automated Installer...${NC}"

# 1. Check for Sudo/Root to install dependencies
if [ "$EUID" -ne 0 ]; then
  echo -e "${BLUE}Asking for sudo permissions to install dependencies...${NC}"
  sudo -v
fi

# 2. Install System Dependencies (Python 3.10 is critical for stability)
echo -e "${GREEN}[1/5] Installing system dependencies (Python 3.10, Git, Libraries)...${NC}"
sudo apt update -y
sudo apt install -y wget git python3.10 python3.10-venv python3-pip libgl1 libglib2.0-0 google-perftools

# 3. Clone WebUI Forge
INSTALL_DIR="stable-diffusion-webui-forge"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Directory '$INSTALL_DIR' already exists.${NC}"
    read -p "Do you want to delete it and reinstall? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${BLUE}Skipping clone step...${NC}"
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}[2/5] Cloning WebUI Forge Repository...${NC}"
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git $INSTALL_DIR
fi

cd $INSTALL_DIR

# 4. Configure Python 3.10 Path
# We edit webui-user.sh to force the use of Python 3.10, avoiding Python 3.11/3.12 issues.
echo -e "${GREEN}[3/5] Configuring environment to use Python 3.10...${NC}"
if [ -f "webui-user.sh" ]; then
    # Uncomment/Add python_cmd
    sed -i 's/#python_cmd="python3"/python_cmd="python3.10"/' webui-user.sh
    # If the line wasn't found (because file changed), append it
    if ! grep -q 'python_cmd="python3.10"' webui-user.sh; then
        echo 'python_cmd="python3.10"' >> webui-user.sh
    fi
else
    # Create the file if it doesn't exist
    echo '#!/bin/bash' > webui-user.sh
    echo 'python_cmd="python3.10"' >> webui-user.sh
fi

# 5. Download FLUX.1 [schnell] Model
MODEL_DIR="models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
MODEL_FILE="flux1-schnell-fp8.safetensors"

echo -e "${GREEN}[4/5] Downloading FLUX.1 [schnell] model (approx. 11GB)...${NC}"
echo -e "${BLUE}This may take a while depending on your internet speed.${NC}"

if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
    echo -e "${BLUE}Model already exists. Skipping download.${NC}"
else
    wget -O "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL" --progress=bar:force
fi

# 6. Final Permissions
chmod +x webui.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "To start the generator:"
echo -e "1. ${BLUE}cd $INSTALL_DIR${NC}"
echo -e "2. ${BLUE}./webui.sh${NC}"
echo -e ""
echo -e "First launch will take a few minutes to install Python requirements."
echo -e "Open your browser at: http://127.0.0.1:7860"

# Optional: Ask to run immediately
read -p "Do you want to run it now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./webui.sh
fi