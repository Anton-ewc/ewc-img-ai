#!/bin/bash

# ==========================================
# FLUX.1 + Forge "Smart" Installer
# (Auto-detects RTX 50-Series vs Standard)
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

echo -e "${BLUE}Starting Smart Installer...${NC}"

# ---------------------------------------------------------
# 1. System Prep & Network Optimization
# ---------------------------------------------------------
echo -e "${GREEN}[1/8] Installing System Dependencies...${NC}"
# Git config to prevent download drops
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# Install tools
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools

# ---------------------------------------------------------
# 2. Miniconda Setup (Isolated Python)
# ---------------------------------------------------------
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${GREEN}[2/8] Installing Miniconda...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
else
    echo -e "${BLUE}Miniconda detected. Skipping.${NC}"
fi

source "$CONDA_DIR/bin/activate"

if { conda env list | grep -q 'forge-env'; }; then
    echo -e "${BLUE}Environment 'forge-env' exists. Skipping.${NC}"
else
    echo -e "${GREEN}[3/8] Creating Python 3.10 Environment...${NC}"
    conda create -n forge-env python=3.10 -y
fi

conda activate forge-env

# ---------------------------------------------------------
# 3. INTELLIGENT HARDWARE DETECTION
# ---------------------------------------------------------
echo -e "${GREEN}[4/8] Detecting GPU and Selecting Drivers...${NC}"

if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA drivers not found. Install drivers first.${NC}"
    exit 1
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
echo -e "${YELLOW}Detected GPU: $GPU_NAME${NC}"

# Clean start for PyTorch
pip uninstall -y torch torchvision torchaudio xformers

# --- Logic Branch ---
if [[ "$GPU_NAME" == *"RTX 50"* ]] || [[ "$GPU_NAME" == *"Blackwell"* ]]; then
    # CASE A: RTX 50-Series (Needs Nightly / CUDA 12.6+)
    echo -e "${BLUE}>> Hardware Match: RTX 50-Series detected.${NC}"
    echo -e "${BLUE}>> Installing PyTorch NIGHTLY (Required for this card)...${NC}"
    
    # We allow the pre-release nightly index
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126

elif [[ "$GPU_NAME" == *"K80"* ]] || [[ "$GPU_NAME" == *"M60"* ]]; then
    # CASE B: Obsolete Cards
    echo -e "${RED}>> CRITICAL WARNING: Your GPU is too old for FLUX.${NC}"
    echo -e "${RED}>> Installation will proceed, but it will likely crash.${NC}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

else
    # CASE C: Standard Cards (RTX 30xx, 40xx, T4, A10)
    echo -e "${BLUE}>> Hardware Match: Standard Modern GPU.${NC}"
    echo -e "${BLUE}>> Installing PyTorch STABLE (CUDA 12.1)...${NC}"
    
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
fi

# ---------------------------------------------------------
# 4. Install WebUI Forge
# ---------------------------------------------------------
echo -e "${GREEN}[5/8] Downloading WebUI Forge...${NC}"
# Remove old installs to prevent conflicts
rm -rf "$INSTALL_DIR"

# Try Git Clone first, fallback to ZIP if it fails
if git clone --depth 1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$INSTALL_DIR"; then
    echo -e "${BLUE}Git clone successful.${NC}"
else
    echo -e "${YELLOW}Git failed. Using ZIP download fallback...${NC}"
    wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
    unzip forge.zip
    mv stable-diffusion-webui-forge-main "$INSTALL_DIR"
    rm forge.zip
fi

# ---------------------------------------------------------
# 5. Download FLUX Model
# ---------------------------------------------------------
echo -e "${GREEN}[6/8] Downloading FLUX.1 [schnell] Model...${NC}"
mkdir -p "$MODEL_DIR"
# Retry up to 5 times for stability
wget -c -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force --tries=5

# ---------------------------------------------------------
# 6. Apply Root & Remote Access Patches
# ---------------------------------------------------------
echo -e "${GREEN}[7/8] Patching Configuration...${NC}"
cd "$INSTALL_DIR"

# Patch 1: Allow running as Root
sed -i 's/if \[ $(id -u) -eq 0 \]/if [ false ]/' webui.sh

# Patch 2: Enable Remote Access (Listen on 0.0.0.0)
if [ ! -f "webui-user.sh" ]; then
    echo '#!/bin/bash' > webui-user.sh
fi
# Add arguments if not present
if ! grep -q "COMMANDLINE_ARGS" webui-user.sh; then
    echo 'export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"' >> webui-user.sh
else
    # Replace existing args
    sed -i 's/export COMMANDLINE_ARGS=.*/export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"/' webui-user.sh
fi

# ---------------------------------------------------------
# 7. Create Launcher
# ---------------------------------------------------------
echo -e "${GREEN}[8/8] Finalizing...${NC}"
cd "$HOME"

cat <<EOT > run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate"
conda activate forge-env
cd "$INSTALL_DIR"
# Ensure we use the isolated Python
export python_cmd="python"
./webui.sh
EOT

chmod +x run_forge.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Detected GPU: $GPU_NAME"
echo -e "To start, run: ${BLUE}./run_forge.sh${NC}"

# Auto-start prompt
read -p "Do you want to run it now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./run_forge.sh
fi