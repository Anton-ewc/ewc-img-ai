#!/bin/bash
set -e

# --- Paths & Colors ---
INSTALL_DIR="$HOME/forge"
CONDA_DIR="$HOME/miniconda3"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}Executing Injection Fix v16...${NC}"

# 1. Environment Activation
source "$CONDA_DIR/bin/activate"
conda activate forge-env

# 2. Manual Repo Injection (The Missing Pieces)
mkdir -p "$INSTALL_DIR/repositories"
cd "$INSTALL_DIR/repositories"

echo -e "${GREEN}Injecting missing Forge logic modules...${NC}"

# Fix: huggingface_guess (This was your specific error)
if [ ! -d "huggingface_guess" ]; then
    wget -O hg.zip https://github.com/lllyasviel/huggingface_guess/archive/refs/heads/main.zip
    unzip -q hg.zip && mv huggingface_guess-main huggingface_guess && rm hg.zip
fi

# Fix: BLIP (Prevents the next warning/crash)
if [ ! -d "BLIP" ]; then
    wget -O blip.zip https://github.com/salesforce/BLIP/archive/refs/heads/main.zip
    unzip -q blip.zip && mv BLIP-main BLIP && rm blip.zip
fi

# Fix: WebUI Assets
if [ ! -d "stable-diffusion-webui-assets" ]; then
    wget -O assets.zip https://github.com/AUTOMATIC1111/stable-diffusion-webui-assets/archive/refs/heads/master.zip
    unzip -q assets.zip && mv stable-diffusion-webui-assets-master stable-diffusion-webui-assets && rm assets.zip
fi

# 3. CRITICAL: Registering the modules so Python sees them
# We add these folders to the Python path directly in the launcher
echo -e "${GREEN}Updating Launcher for module registration...${NC}"

cd "$HOME"
cat <<EOT > run_forge.sh
#!/bin/bash
source "$CONDA_DIR/bin/activate"
conda activate forge-env

# Export paths so Python finds our manual injections
export PYTHONPATH="\$PYTHONPATH:$INSTALL_DIR/repositories/huggingface_guess:$INSTALL_DIR/repositories/BLIP"
export can_run_as_root=1
export TORCH_CUDA_ARCH_LIST="12.0"
export LD_PRELOAD=/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

cd "$INSTALL_DIR"
# Blackwell optimized flags
python launch.py --listen --enable-insecure-extension-access --cuda-malloc --no-half-vae
EOT

chmod +x run_forge.sh

echo -e "${GREEN}INJECTION COMPLETE. Running now...${NC}"
./run_forge.sh

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE!             ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Run this command to start:"

echo -e "${GREEN} URL: http://<YOUR_IP>:7860"