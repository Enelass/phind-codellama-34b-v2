#!/bin/zsh
set -e
setopt null_glob
setopt no_nomatch


# This script reassembles file chunks, verifies the SHA256 checksum,
# and moves the file to the ~/.ollama directory on macOS.

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Timestamp ---
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# --- Timestamp ---
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# --- Configuration ---
# The directory where the model chunks are located.
CHUNKS_DIR="model-chunks"
# The pattern for the chunk files.
CHUNK_PATTERN="part_*"
# The expected SHA256 checksum of the final reassembled file.
EXPECTED_SHA="45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2"
# The name of the final reassembled file.
REASSEMBLED_FILE="sha256-45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2"
# The target directory for the final model file.
TARGET_DIR="$HOME/.ollama/models/blobs"

# --- Script Logic ---

printf '%s\n' "[`timestamp`] Starting model reassembly process..."

# Check if file already exists in target dir
if [[ -f "$TARGET_DIR/$REASSEMBLED_FILE" ]]; then
  printf '[%s] %b✔%b Model already exists at %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR/$REASSEMBLED_FILE"
  exit 0
fi

# 1. Reassemble the file from chunks
printf '[%s] Reassembling file from chunks in %s ...\n' "$(timestamp)" "$CHUNKS_DIR"
chunk_files=()
while IFS= read -r -d '' f; do
  chunk_files+=("$f")
done < <(find "$CHUNKS_DIR" -type f -name "$CHUNK_PATTERN" -print0 | sort -z)

if [[ ${#chunk_files[@]} -eq 0 ]]; then
  printf '[%s] %b✗%b No chunk files found in %s matching %s\n' "$(timestamp)" "$RED" "$NC" "$CHUNKS_DIR" "$CHUNK_PATTERN"
  exit 1
fi

# Spinner for reassembly
SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
spinner_pid=""
spinner_msg="please wait a bit while reassembling"
cleanup_spinner() {
  if [[ -n "$spinner_pid" ]]; then
    kill "$spinner_pid" >/dev/null 2>&1
    wait "$spinner_pid" 2>/dev/null || true
    spinner_pid=""
    printf "\r\033[K"
  fi
}
trap cleanup_spinner EXIT INT TERM

start_spinner() {
  spinner_msg="$1"
  local i=0
  (
    while :; do
      printf "\r[%s] %s %s" "$(timestamp)" "${SPINNER_FRAMES[$i]}" "$spinner_msg"
      i=$(( (i+1) % ${#SPINNER_FRAMES[@]} ))
      sleep 0.1
    done
  ) &
  spinner_pid=$!
}

stop_spinner() {
  cleanup_spinner
  printf "[%s] %b✔%b Reassembly complete\n" "$(timestamp)" "$GREEN" "$NC"
}

start_spinner "please wait a bit while reassembling"
cat "${chunk_files[@]}" > "$REASSEMBLED_FILE"
stop_spinner

printf '[%s] %b✔%b File reassembled as %s\n' "$(timestamp)" "$GREEN" "$NC" "$REASSEMBLED_FILE"

# 4. Verify the SHA256 checksum
printf '[%s] Verifying SHA256 checksum ...\n' "$(timestamp)"
CALCULATED_SHA=$(shasum -a 256 "$REASSEMBLED_FILE" | awk '{print $1}')
printf '[%s] Expected SHA: %s\n' "$(timestamp)" "$EXPECTED_SHA"
printf '[%s] Calculated SHA: %s\n' "$(timestamp)" "$CALCULATED_SHA"

if [[ "$CALCULATED_SHA" != "$EXPECTED_SHA" ]]; then
  printf '[%s] %b✗%b SHA256 checksum mismatch. Removing file.\n' "$(timestamp)" "$RED" "$NC"
  rm "$REASSEMBLED_FILE"
  exit 1
else
  printf '[%s] %b✔%b Checksum verified\n' "$(timestamp)" "$GREEN" "$NC"
fi

# 5. Move the reassembled file to the target directory
if mv "$REASSEMBLED_FILE" "$TARGET_DIR/"; then
  printf '[%s] %b✔%b File moved to %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR/$REASSEMBLED_FILE"
  printf '[%s] %b✔%b Model setup complete! Model is now available at %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR/$REASSEMBLED_FILE"
else
  printf '[%s] %b✗%b Failed to move file to %s\n' "$(timestamp)" "$RED" "$NC" "$TARGET_DIR"
  exit 1
fi