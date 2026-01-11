#!/bin/bash
set -e

# --- Paths & Colors ---
INSTALL_DIR="$HOME/forge"
CONDA_DIR="$HOME/miniconda3"
MODEL_URL="https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}Executing Master v14...${NC}"

# 1. System Dependencies
sudo apt update -y
sudo apt install -y wget git unzip libgl1 libglib2.0-0 google-perftools curl pkg-config libcairo2-dev libtcmalloc-minimal4

# 2. Miniconda & Env
if [ ! -d "$CONDA_DIR" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi
source "$CONDA_DIR/bin/activate"
conda create -n forge-env python=3.10 -y || echo "Env exists"
conda activate forge-env

# 3. CRITICAL: PyTorch for Blackwell (RTX 5060 Ti)
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128 --no-cache-dir
pip install joblib svglib # Missing from previous runs

# 4. Forge Source (ZIP Method - NO GIT CLONE)
[ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR"
wget -O forge.zip https://github.com/lllyasviel/stable-diffusion-webui-forge/archive/refs/heads/main.zip
unzip -q forge.zip
mv stable-diffusion-webui-forge-main "$INSTALL_DIR"
rm forge.zip

# 5. Model Download
mkdir -p "$INSTALL_DIR/models/Stable-diffusion"
wget -O "$INSTALL_DIR/models/Stable-diffusion/flux1-schnell-fp8.safetensors" "$MODEL_URL" --progress=bar:force

# 6. Manual Repo Planting (Fixes the "Username for Github" loop)
mkdir -p "$INSTALL_DIR/repositories"
cd "$INSTALL_DIR/repositories"
# Fix Stability-AI
wget -O sd.zip https://github.com/CompVis/stable-diffusion/archive/refs/heads/main.zip
unzip -q sd.zip && mv stable-diffusion-main stable-diffusion-stability-ai && rm sd.zip
# Fix Assets
wget -O assets.zip https://github.com/AUTOMATIC1111/stable-diffusion-webui-assets/archive/refs/heads/master.zip
unzip -q assets.zip && mv stable-diffusion-webui-assets-master stable-diffusion-webui-assets && rm assets.zip

# 7. Code Patching
cd "$INSTALL_DIR"
# Disable ALL git cloning in the Python logic
LAUNCH_UTILS=$(find . -name "launch_utils.py" | head -n 1)
sed -i 's/git_clone(/# git_clone(/g' "$LAUNCH_UTILS"
# Patch webui.sh for root access
sed -i 's/can_run_as_root=0/can_run_as_root=1/' webui.sh

# 8. Create Final Launcher
cd "$HOME"
cat <<EOT > run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate"
conda activate forge-env
export can_run_as_root=1
export TORCH_CUDA_ARCH_LIST="12.0"
export LD_PRELOAD=/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
cd "$INSTALL_DIR"
python launch.py --listen --enable-insecure-extension-access --cuda-malloc --no-half-vae
EOT
chmod +x run_forge.sh

echo -e "${GREEN}DONE. Run with: ./run_forge.sh${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Run this command to start:"

echo -e "${GREEN} URL: http://<YOUR_IP>:7860"