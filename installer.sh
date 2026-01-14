#!/bin/bash

# ==========================================
# FLUX.1 [schnell] + WebUI Forge Auto-Installer
# (v6: HTTP/1.1 Force + ZIP Fallback Edition)
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
        h) echo "Usage: $0 -p <password> -h"; exit 0;;
        *) echo "Invalid option: -$OPTARG" >&2; exit 1;;
    esac
done

if [ -z "$API_PASSWORD" ]; then
    echo "Error: API password is required"
    exit 1
fi

echo "Current dir: ${CURRENT_DIR}"
echo "Home dir: ${HOME_DIR}"
echo -e "${GREEN}Installations dir: ${INSTALLS_DIR}${NC}"
echo ""


# Paths
DEFFUSION_DIR="$INSTALLS_DIR/stable-diffusion-webui-forge"
CONDA_DIR="$INSTALLS_DIR/miniconda3"
MODEL_DIR="$DEFFUSION_DIR/models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
PYTHON_VERSION="3.10"

echo -e "${BLUE}Starting Final Fix Installer...${NC}"

# 1. Install Dependencies (Added 'unzip' for backup method)
echo -e "${GREEN}[1/7] Installing system tools...${NC}"
sudo apt update -y
#sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools curl pkg-config libcairo2-dev
sudo apt install -y build-essential python3-dev libjpeg-dev zlib1g-dev libpng-dev libtiff-dev libfreetype6-dev liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev

python3 -m pip install --upgrade pip setuptools wheel
pip install joblib Pillow

# 2. CRITICAL GIT FIXES (Solves "curl 92" and "RPC failed")
echo -e "${GREEN}[2/7] Applying Git Network Fixes (Force HTTP/1.1)...${NC}"
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# 3. Install Miniconda
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${BLUE}[3/7] Installing Miniconda...${NC}"
	wget -qO - https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh | bash -s --
    #wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    #bash miniconda.sh -b -p "$HOME/miniconda3"
    #bash miniconda.sh -b -p "$CONDA_DIR"
    #bash miniconda.sh -b -p "$HOME/miniconda3"
    #rm miniconda.sh
else
    echo -e "${GREEN}[3/7]Miniconda already installed.${NC}"
fi


if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "${BLUE}No Conda environment is active.${NC}"
    echo "${BLUE}Activating Conda.${NC}"
	#source "$HOME/miniconda3/bin/activate"
	source "$CONDA_DIR/bin/activate"
else
    echo "Active environment: $CONDA_DEFAULT_ENV"
    echo "Location: $CONDA_PREFIX"
fi

# 4. Create Environment
echo -e "${GREEN}[4/7] Creating environment $ENV_NAME...${NC}"
if { conda env list | grep -q "$ENV_NAME"; }; then
    echo -e "${BLUE}Environment $ENV_NAME exists. Skipping.${NC}"
else
    echo -e "${GREEN}Creating Python $PYTHON_VERSION environment...${NC}"
    conda create -n $ENV_NAME python=$PYTHON_VERSION -y
fi

if { conda list -n forge | grep "python" | grep -q $PYTHON_VERSION; }; then
    echo -e "${BLUE}Python $PYTHON_VERSION is already installed. Skipping.${NC}"
else
    echo -e "${GREEN}Installing Python $PYTHON_VERSION...${NC}"
    conda install python=$PYTHON_VERSION -y
fi

echo -e "${GREEN}[5/7] Activating environment $ENV_NAME...${NC}"
# Initialize conda for this shell session (avoids needing 'conda init' globally)
eval "$($CONDA_DIR/bin/conda shell.bash hook)"
conda activate $ENV_NAME

# 5. Download WebUI Forge (The "Fail-Safe" Method)
if [ ! -d "$DEFFUSION_DIR" ]; then
    echo -e "${GREEN}[5/7] Downloading WebUI Forge...${NC}"

    #git clone --depth 1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$INSTALL_DIR"
    # Attempt 1: Git Clone (Optimized)
    #if git clone --depth 1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$HOME/stable-diffusion-webui-forge"; then
    if git clone --depth 1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$DEFFUSION_DIR"; then
        echo -e "${BLUE}Git clone successful.${NC}"
    else
        echo -e "${RED}Git clone failed again. Switching to ZIP download method...${NC}"
        exit 1
        # Attempt 2: ZIP Download (Bypasses Git Protocol completely)
        wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
        unzip forge.zip
        mv stable-diffusion-webui-forge-main "$DEFFUSION_DIR"
        rm forge.zip
        echo -e "${BLUE}ZIP installation successful.${NC}"
    fi
else
    echo -e "${BLUE}WebUI Forge already exists. Skipping.${NC}"
fi


# Remove previous broken attempts
#if [ -d "$INSTALL_DIR" ]; then
#    rm -rf "$INSTALL_DIR"
#fi


# 6. Download FLUX Model
if [ -f "$MODEL_DIR/flux1-schnell-fp8.safetensors" ]; then
    echo -e "${GREEN}[6/7] Model flux1 exists.${NC}"
else
    echo -e "${GREEN}[6/7] Downloading FLUX.1 [schnell] Model...${NC}"
    exit 1
    #mkdir -p "$HOME/stable-diffusion-webui-forge/models/Stable-diffusion"
    mkdir -p "$MODEL_DIR"
    # Retry loop for model download
    #wget -c -O "$HOME/stable-diffusion-webui-forge/models/Stable-diffusion/flux1-schnell-fp8.safetensors" "https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors" --progress=bar:force --tries=5
    wget -c -O "$MODEL_DIR/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force --tries=5
fi

# Patch webui.sh to remove the "root" check
sed -i 's/can_run_as_root=0/can_run_as_root=1/' $DEFFUSION_DIR/webui.sh

# 7. Create Launcher
echo -e "${GREEN}[7/7] Creating launcher...${NC}"
if [ -f "$INSTALLS_DIR/run_forge.sh" ]; then
    echo -e "${BLUE}Launcher already exists. Skipping.${NC}"
else
    exit 1
    cat <<EOT > run_forge.sh
    #!/bin/bash
    source "$CONDA_DIR/bin/activate"
    conda activate forge-env
    cd "$DEFFUSION_DIR"
    # Force Git updates to use HTTP 1.1 inside the app too
    #git config --global http.version HTTP/1.1
    #./webui.sh
    #python launch.py --listen --enable-insecure-extension-access
    #python launch.py --listen --enable-insecure-extension-access --cuda-malloc --no-half-vae
    python launch.py --listen --api --gradio-auth "admin:$API_PASSWORD" --enable-insecure-extension-access --cuda-malloc --no-half-vae
EOT
chmod +x "$INSTALLS_DIR/run_forge.sh"
fi



echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Run this command to start:"
echo -e "${BLUE}./run_forge.sh${NC}"

cd $INSTALLS_DIR
./run_forge.sh

#cd /workspace/

# 1. Enter the directory
#cd ~/stable-diffusion-webui-forge

# 2. Patch webui.sh to remove the "root" check
# We use sed to find the check (checking for id 0) and comment it out
#sed -i 's/if \[ $(id -u) -eq 0 \]/if [ false ]/' webui.sh
#sed -i 's/can_run_as_root=0/can_run_as_root=0/' webui.sh
#sed -i 's/can_run_as_root=0/can_run_as_root=0/' /root/stable-diffusion-webui-forge/webui.sh

# 3. Enable remote access (Required if you are on a headless server)
# This adds "--listen" so you can connect from another computer
#sed -i 's/#export COMMANDLINE_ARGS=""/export COMMANDLINE_ARGS="--listen --enable-insecure-extension-access"/' webui-user.sh

# 4. Run the launcher again
#cd ..
#./run_forge.sh