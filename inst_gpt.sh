#!/bin/bash
set -e
# ==========================================
# Full Installer Script with Your Models
# ==========================================
# wget -qO - https://raw.githubusercontent.com/Anton-ewc/ewc-img-ai/refs/heads/main/inst_gpt.sh | bash -s -- 

BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PASSWORD=""
CURRENT_DIR=$(pwd 2>/dev/null || echo ".")
HOME_DIR="/workspace"
INSTALLS_DIR="$HOME_DIR"
ENV_NAME="forge-env"
DEFFUSION_DIR="$INSTALLS_DIR/stable-diffusion-webui-forge"
CONDA_DIR="$INSTALLS_DIR/miniconda3"
MODEL_DIR="$DEFFUSION_DIR/models/Stable-diffusion"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
PYTHON_VERSION="3.10"


# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--password) PASSWORD="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$PASSWORD" ]; then
    echo "Usage: $0 -p <password>"
    exit 1
fi

echo -e "${BLUE}Starting Full Installer with Your Models...${NC}"
echo -e "${BLUE}Current dir: ${CURRENT_DIR}${NC}"
echo -e "${BLUE}Home dir: ${HOME_DIR}${NC}"
echo -e "${BLUE}Installations dir: ${INSTALLS_DIR}${NC}"
echo ""
pause
function pause(){
   read -p "$*"
}
exit 0
exit 1

# -------------------------
# 1. System dependencies
# -------------------------
echo -e "${BLUE}[1/8] Installing system packages...${NC}"
apt update -y
apt install -y wget git unzip curl build-essential python3-dev \
               libjpeg-dev zlib1g-dev libpng-dev libcairo2-dev pkg-config \
               google-perftools libgl1 libglib2.0-0 ffmpeg libtiff-dev \
               libfreetype6-dev liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev


# -------------------------
# 2. Python virtual environment
# -------------------------
echo -e "${BLUE}[2/8] Setting up Python virtual environment...${NC}"
python3 -m venv /venv/forge-env
source /venv/forge-env/bin/activate
pip install --upgrade pip setuptools wheel packaging
python3 -m pip install --upgrade pip setuptools wheel joblib Pillow

# -------------------------
# 4. Fix conflicting packages
# -------------------------
echo "[2.1/8] Fixing common package conflicts..."
pip install --upgrade --force-reinstall \
    pydantic pydantic-core protobuf Pillow

# -------------------------
# 5. Additional Python packages
# -------------------------
echo "[2.2/8] Installing additional Python packages..."
pip install insightface svglib tinycss2 cssselect2 webencodings \
            joblib tqdm matplotlib scikit-learn scikit-image easydict \
            cython albumentations prettytable

# -------------------------
# 3. Git network fixes
# -------------------------
echo -e "${YELLOW}[2.1/8] Applying Git Network Fixes (Force HTTP/1.1)...${NC}"
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# -------------------------
# 3. PyTorch + CUDA 12.8
# -------------------------
echo -e "${BLUE}[3/8] Installing PyTorch with CUDA 12.8...${NC}"
pip install --index-url https://download.pytorch.org/whl/cu128 \
            torch==2.10.0+cu128 torchvision==0.25.0+cu128 torchaudio==2.10.0+cu128 \
            nvidia-cuda-runtime-cu12==12.8.90 nvidia-cuda-nvrtc-cu12==12.8.93 \
            nvidia-cublas-cu12==12.8.4.1 nvidia-cudnn-cu12==9.10.2.21 \
            nvidia-cusparse-cu12==12.5.8.93 nvidia-nccl-cu12==2.27.5 \
            triton==3.6.0 fsspec filelock jinja2 sympy networkx numpy pillow \
            cuda-bindings==12.9.4 cuda-pathfinder==1.2.2

# -------------------------
# 4. Install Miniconda
# -------------------------
if [ ! -d "$CONDA_DIR" ]; then
    echo -e "${BLUE}[4/8] Installing Miniconda...${NC}"
	wget -qO - https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh | bash -s --
    #wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    #bash miniconda.sh -b -p "$HOME/miniconda3"
    #bash miniconda.sh -b -p "$CONDA_DIR"
    #bash miniconda.sh -b -p "$HOME/miniconda3"
    #rm miniconda.sh
else
    echo -e "${GREEN}[4/8]Miniconda already installed.${NC}"
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

# -------------------------
# 5. Activate Conda environment
# -------------------------
if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "${BLUE}No Conda environment is active.${NC}"
    echo "${BLUE}Activating Conda.${NC}"
	#source "$HOME/miniconda3/bin/activate"
    source "$CONDA_DIR/bin/activate"
    conda activate forge-env
else
    echo -e "${GREEN}Active environment: $CONDA_DEFAULT_ENV${NC}"
    echo -e "${GREEN}Location: $CONDA_PREFIX${NC}"
fi


# -------------------------
# 6. Your models
# -------------------------
#echo "[6/8] Setting up your models..."
# ------------------------------
# 6/7 Download FLUX Model
# ------------------------------
echo -e "${GREEN}[6/8] Checking FLUX model...${NC}"
MODEL_FILE="$MODEL_DIR/flux1-schnell-fp8.safetensors"
if [ -f "$MODEL_FILE" ]; then
    echo -e "${GREEN}[6/7] Model flux1 exists.${NC}"
else
    echo -e "${GREEN}[6/7] Downloading FLUX.1 [schnell] Model...${NC}"
    mkdir -p "$MODEL_DIR"
    wget -c -O "$MODEL_FILE" "$MODEL_URL" --progress=bar:force --tries=5
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[6/7] Model downloaded successfully!${NC}"
    else
        echo -e "${RED}[6/7] ERROR: Model download failed.${NC}"
        exit 1
    fi
fi

#MODEL_DIR="/workspace/models"
#mkdir -p $MODEL_DIR

# Models from your first code
#cp /mnt/data/first_code_models/stylegan2.pth $MODEL_DIR/
#cp /mnt/data/first_code_models/arcface.pth $MODEL_DIR/
#cp /mnt/data/first_code_models/vggface.pth $MODEL_DIR/
#cp /mnt/data/first_code_models/other_model1.pth $MODEL_DIR/
#cp /mnt/data/first_code_models/other_model2.pth $MODEL_DIR/

echo "Models copied to $MODEL_DIR"

# -------------------------
# 7. Workspace and run script
# -------------------------
echo "[7/8] Creating workspace and launcher..."
mkdir -p /workspace
echo "#!/bin/bash
source /venv/forge-env/bin/activate
python3 /workspace/forge_main.py \"\$@\"" > /workspace/run_forge.sh
chmod +x /workspace/run_forge.sh

# -------------------------
# 8. Final message
# -------------------------
echo "=========================================="
echo "INSTALLATION COMPLETE!"
echo "Models located at: $MODEL_DIR"
echo "Run Forge with: ./run_forge.sh"
echo "=========================================="
