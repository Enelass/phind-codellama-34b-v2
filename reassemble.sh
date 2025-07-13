#!/bin/zsh

# This script reassembles file chunks, verifies the SHA256 checksum,
# and moves the file to the ~/.ollama directory on macOS.

set -e

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Configuration ---
# The directory where the model chunks are located.
CHUNKS_DIR="model-chunks"
# The pattern for the chunk files.
CHUNK_PATTERN="part_*"
# The expected SHA256 checksum of the final reassembled file.
EXPECTED_SHA="45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2"
# The name of the final reassembled file.
REASSEMBLED_FILE="phind-codellama-34b-v2.gguf"
# The target directory for the final model file.
TARGET_DIR="$HOME/.ollama"

# --- Script Logic ---

echo -e "${BLUE}Starting the model reassembly process...${NC}"

# 1. Verify we are on macOS
echo -e "\n${BLUE}1. Verifying operating system...${NC}"
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}Error: This script is intended to be run on macOS (Darwin) only.${NC}"
  exit 1
fi
echo -e "${GREEN}   -> Success: macOS detected.${NC}"

# 2. Verify the target directory exists
echo -e "\n${BLUE}2. Verifying target directory ($TARGET_DIR) exists...${NC}"
if [[ ! -d "$TARGET_DIR" ]]; then
  echo -e "${RED}Error: The target directory '$TARGET_DIR' does not exist.${NC}"
  echo -e "${YELLOW}Please make sure Ollama is installed and has been run at least once.${NC}"
  exit 1
fi
echo -e "${GREEN}   -> Success: Target directory found.${NC}"

# 3. Reassemble the file from chunks
echo -e "\n${BLUE}3. Reassembling file from chunks in '$CHUNKS_DIR'...${NC}"
if ! ls "$CHUNKS_DIR/$CHUNK_PATTERN" > /dev/null 2>&1; then
    echo -e "${RED}Error: No chunk files found in '$CHUNKS_DIR' matching '$CHUNK_PATTERN'.${NC}"
    exit 1
fi
cat "$CHUNKS_DIR/$CHUNK_PATTERN" > "$REASSEMBLED_FILE"
echo -e "${GREEN}   -> Success: File reassembled as '$REASSEMBLED_FILE'.${NC}"

# 4. Verify the SHA256 checksum
echo -e "\n${BLUE}4. Verifying SHA256 checksum...${NC}"
# On macOS, shasum is the default
CALCULATED_SHA=$(shasum -a 256 "$REASSEMBLED_FILE" | awk '{print $1}')

echo -e "   - ${YELLOW}Expected SHA:${NC} $EXPECTED_SHA"
echo -e "   - ${YELLOW}Calculated SHA:${NC} $CALCULATED_SHA"

if [[ "$CALCULATED_SHA" != "$EXPECTED_SHA" ]]; then
  echo -e "${RED}Error: SHA256 checksum mismatch.${NC}"
  rm "$REASSEMBLED_FILE" # Clean up the incorrect file
  exit 1
fi
echo -e "${GREEN}   -> Success: Checksum verified.${NC}"

# 5. Move the reassembled file to the target directory
echo -e "\n${BLUE}5. Moving '$REASSEMBLED_FILE' to '$TARGET_DIR'...${NC}"
mv "$REASSEMBLED_FILE" "$TARGET_DIR/"
echo -e "${GREEN}   -> Success: File moved.${NC}"

echo -e "\n${GREEN}--------------------------------------------------${NC}"
echo -e "${GREEN}✅ Model setup complete!${NC}"
echo -e "${GREEN}The model '$REASSEMBLED_FILE' is now available in '$TARGET_DIR'.${NC}"
echo -e "${GREEN}--------------------------------------------------${NC}"