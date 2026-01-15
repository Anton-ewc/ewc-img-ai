#!/bin/bash

# ==========================================
# RTX 50-Series Optimized Forge Installer
# Fixes: CUDA sm_120, joblib, and LoRA paths
# ==========================================

set -e
#set +e  # Don't exit on error - continue execution

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

#wget -qO - https://raw.githubusercontent.com/Anton-ewc/ewc-img-ai/refs/heads/main/installer.sh | bash -s -- 

# Get current directory, fallback to . if pwd fails (can happen when piped)
CURRENT_DIR=$(pwd 2>/dev/null || echo ".")
HOME_DIR="$HOME"
INSTALLS_DIR="$HOME_DIR"
ENV_NAME="forge-env"

API_PASSWORD=$1

while getopts "p:h" opt; do
    case $opt in
        p) API_PASSWORD=$OPTARG ;;
        h) echo "Usage: $0 -p <password>"; exit 0;;
    esac
done

if [ -z "$API_PASSWORD" ]; then
    echo -e "${RED}Error: API password is required (-p password)${NC}"
    exit 1
fi

echo "Current dir: ${CURRENT_DIR}"
echo "Home dir: ${HOME_DIR}"
echo -e "${GREEN}Installations dir: ${INSTALLS_DIR}${NC}"
echo ""


# Paths
DEFFUSION_DIR="$INSTALLS_DIR/stable-diffusion-webui-forge"
CONDA_DIR="$INSTALLS_DIR/miniconda3"
# FIX: LoRAs MUST go in the Lora folder, not Stable-diffusion
MODEL_DIR="$DEFFUSION_DIR/models/Lora"
CHECKPOINT_DIR="$DEFFUSION_DIR/models/Stable-diffusion"
MODELFILE="lora.safetensors"
MODEL_URL="https://huggingface.co/kp-forks/Flux-uncensored/resolve/main/$MODELFILE"
PYTHON_VERSION="3.10"

echo -e "${BLUE}Starting RTX 50-Series Installer...${NC}"

# 1. Install System Dependencies
echo -e "${GREEN}[1/7] Installing system tools...${NC}"
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools curl build-essential python3-dev

# 2. Install/Activate Conda
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${BLUE}[2/7] Installing Miniconda...${NC}"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi
source "$CONDA_DIR/bin/activate" ""

# 3. Create & Setup Environment
echo -e "${GREEN}[3/7] Setting up Environment...${NC}"
conda create -n $ENV_NAME python=$PYTHON_VERSION -y || echo "Env exists"
conda activate $ENV_NAME

# CRITICAL: Install RTX 50-series compatible Torch (sm_120 support)
echo -e "${BLUE}Installing CUDA 12.4+ Compatible PyTorch for RTX 5060 Ti...${NC}"
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
pip install joblib insightface Pillow setuptools wheel

# 4. Download Forge
if [ ! -d "$DEFFUSION_DIR" ]; then
    echo -e "${GREEN}[4/7] Cloning Forge...${NC}"
    git clone --depth 1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$DEFFUSION_DIR"
fi

# 5. Download LoRA and Base Model
echo -e "${GREEN}[5/7] Handling Models...${NC}"
mkdir -p "$MODEL_DIR"
mkdir -p "$CHECKPOINT_DIR"

if [ ! -f "$MODEL_DIR/$MODELFILE" ]; then
    wget -c -O "$MODEL_DIR/$MODELFILE" "$MODEL_URL"
fi

# IMPORTANT: You need at least one BASE model (Checkpoint) or Forge won't start
if [ ! -f "$CHECKPOINT_DIR/sd_xl_base_1.0.safetensors" ]; then
    echo -e "${BLUE}Downloading SDXL Base as primary checkpoint...${NC}"
    wget -c -O "$CHECKPOINT_DIR/sd_xl_base_1.0.safetensors" "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
fi

# 6. Create Launcher
echo -e "${GREEN}[6/7] Creating launcher...${NC}"
cat <<EOT > $INSTALLS_DIR/run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate" $ENV_NAME
cd "$DEFFUSION_DIR"
# Optimization for 50-series: bf16 is faster and more stable than full precision
python launch.py --listen --api --gradio-auth "admin:$API_PASSWORD" \
--enable-insecure-extension-access --cuda-malloc --bf16
EOT
chmod +x "$INSTALLS_DIR/run_forge.sh"

echo -e "${GREEN}Fixes applied. Starting WebUI...${NC}"
./run_forge.sh