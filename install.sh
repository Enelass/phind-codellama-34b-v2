#!/bin/zsh

# This script automates the download, extraction, and setup of the
# phind-codellama-34b-v2 model from a GitHub repository.
# It is designed to be run via a single curl command.

set -e

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Configuration ---
# IMPORTANT: Replace this URL with the correct one for your repository.
REPO_URL="https://github.com/<YOUR_GITHUB_USERNAME>/phind-codellama-34b-v2/archive/refs/heads/main.zip"
# The name of the directory inside the zip file (usually repo-name-branch-name)
EXTRACTED_DIR_NAME="phind-codellama-34b-v2-main"
# Temporary directory for the download
TMP_DIR="/tmp"
# Required disk space in Kilobytes (40 GB)
REQUIRED_SPACE_KB=$((40 * 1024 * 1024))

# --- Script Logic ---

echo -e "${BLUE}Starting the automated model download and installation process...${NC}"

# 1. Navigate to the temporary directory
echo -e "\n${BLUE}1. Changing to temporary directory ($TMP_DIR)...${NC}"
cd "$TMP_DIR"
echo -e "${GREEN}   -> Success: Now in $(pwd)${NC}"

# 2. Check for available disk space
echo -e "\n${BLUE}2. Verifying available disk space in $TMP_DIR...${NC}"
AVAILABLE_SPACE_KB=$(df -k "$TMP_DIR" | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$(echo "scale=2; $AVAILABLE_SPACE_KB / 1024 / 1024" | bc)
REQUIRED_SPACE_GB=$(echo "scale=2; $REQUIRED_SPACE_KB / 1024 / 1024" | bc)

echo -e "   - ${YELLOW}Available space:${NC} ${AVAILABLE_SPACE_GB} GB"
echo -e "   - ${YELLOW}Required space:${NC}  ${REQUIRED_SPACE_GB} GB"

if (( AVAILABLE_SPACE_KB < REQUIRED_SPACE_KB )); then
  echo -e "${RED}Error: Not enough free disk space in $TMP_DIR.${NC}"
  echo -e "${RED}Please free up at least ${REQUIRED_SPACE_GB} GB and try again.${NC}"
  exit 1
fi
echo -e "${GREEN}   -> Success: Sufficient disk space available.${NC}"

# 3. Download the repository archive
echo -e "\n${BLUE}3. Downloading repository from GitHub...${NC}"
curl -L -o model_repo.zip "$REPO_URL"
echo -e "${GREEN}   -> Success: Repository downloaded as model_repo.zip${NC}"

# 4. Extract the archive
echo -e "\n${BLUE}4. Extracting repository archive...${NC}"
unzip -q model_repo.zip
echo -e "${GREEN}   -> Success: Archive extracted.${NC}"

# 5. Navigate into the extracted directory
echo -e "\n${BLUE}5. Entering repository directory...${NC}"
if [[ ! -d "$EXTRACTED_DIR_NAME" ]]; then
    echo -e "${RED}Error: Extracted directory '$EXTRACTED_DIR_NAME' not found.${NC}"
    exit 1
fi
cd "$EXTRACTED_DIR_NAME"
echo -e "${GREEN}   -> Success: Now in $(pwd)${NC}"

# 6. Make the reassembly script executable and run it
echo -e "\n${BLUE}6. Running the reassembly script...${NC}"
if [[ ! -f "reassemble.sh" ]]; then
    echo -e "${RED}Error: 'reassemble.sh' not found in the repository.${NC}"
    exit 1
fi
chmod +x reassemble.sh
./reassemble.sh

# 7. Cleanup
echo -e "\n${BLUE}7. Cleaning up temporary files...${NC}"
cd "$TMP_DIR"
rm -rf model_repo.zip "$EXTRACTED_DIR_NAME"
echo -e "${GREEN}   -> Success: Cleaned up temporary files.${NC}"

echo -e "\n${GREEN}--------------------------------------------------${NC}"
echo -e "${GREEN}✅ All steps completed successfully!${NC}"
echo -e "${GREEN}The model should now be available in Ollama.${NC}"
echo -e "${GREEN}--------------------------------------------------${NC}"