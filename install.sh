#!/usr/bin/env bash

set -e

SCRIPT_VERSION="1.1.0" # Update as needed

printf "[%s] %bphind-codellama-34b-v2 installer version: %s%b\n" "$(date "+%Y-%m-%d %H:%M:%S")" "$BLUE" "$SCRIPT_VERSION" "$NC"

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

# --- NPM-style Spinner ---
SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
spinner_pid=""
spinner_msg=""
cleanup_spinner() {
  if [[ -n "$spinner_pid" ]]; then
    kill "$spinner_pid" >/dev/null 2>&1
    wait "$spinner_pid" 2>/dev/null || true
    spinner_pid=""
    # Clear spinner line
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
  local exit_code=$1
  local msg="$2"
  cleanup_spinner
  if [[ "$exit_code" == "0" ]]; then
    printf "[%s] ${GREEN}✔${NC} %s\n" "$(timestamp)" "$msg"
  else
    printf "[%s] ${RED}✗${NC} %s\n" "$(timestamp)" "$msg"
  fi
}

# --- Configuration ---
MANIFEST_URL="https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/34b-v2"
MANIFEST_TARGET_DIR="$HOME/.ollama/models/manifests/registry.ollama.ai/library/phind-codellama"
MANIFEST_TARGET_FILE="$MANIFEST_TARGET_DIR/34b-v2"
SHA256_URL="https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/model-chunks/45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2.sha256"
MODEL_CHUNKS_URL_BASE="https://github.com/Enelass/phind-codellama-34b-v2/raw/refs/heads/main/model-chunks"
if [ -d "./model-chunks" ]; then
  MODEL_CHUNKS_DIR="./model-chunks"
else
  MODEL_CHUNKS_DIR="/tmp/model-chunks-phind-34b-v2"
fi
PART_FIRST="aa"
PART_LAST="nz"
PART_SIZE=52428800 # 50MB in bytes
TOTAL_PARTS=366

# --- OS and Target Directory Checks ---
if [[ "$(uname)" != "Darwin" ]]; then
  printf '[%s] %b✗%b Not macOS (Darwin) - aborting.\n' "$(timestamp)" "$RED" "$NC"
  exit 1
else
  printf '[%s] %b✔%b macOS detected\n' "$(timestamp)" "$GREEN" "$NC"
fi

TARGET_DIR="$HOME/.ollama/models/blobs"
if [[ ! -d "$TARGET_DIR" ]]; then
  printf '[%s] %b!%b Target directory not found, attempting to create: %s\n' "$(timestamp)" "$YELLOW" "$NC" "$TARGET_DIR"
  if mkdir -p "$TARGET_DIR"; then
    printf '[%s] %b✔%b Created target directory: %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR"
  else
    printf '[%s] %b✗%b Failed to create target directory: %s\n' "$(timestamp)" "$RED" "$NC" "$TARGET_DIR"
    printf '[%s] %bPlease make sure Ollama is installed and has been run at least once.%b\n' "$(timestamp)" "$YELLOW" "$NC"
    exit 1
  fi
else
  printf '[%s] %b✔%b Target directory found: %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR"
fi

printf '%s\n' "[`timestamp`] Starting phind-codellama-34b-v2 model download and setup..."
printf '[%s] %bModel chunks will be stored in (and reused from): %s%b\n' "$(timestamp)" "$BLUE" "$MODEL_CHUNKS_DIR" "$NC"
if [ "$MODEL_CHUNKS_DIR" = "./model-chunks" ]; then
  printf '[%s] %bDetected local model-chunks directory, using it for chunk storage and resume.%b\n' "$(timestamp)" "$BLUE" "$NC"
fi

# 1. Check for available disk space (40GB)
REQUIRED_SPACE_KB=$((40 * 1024 * 1024))
AVAILABLE_SPACE_KB=$(df -k . | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$(echo "scale=2; $AVAILABLE_SPACE_KB / 1024 / 1024" | bc)
REQUIRED_SPACE_GB=$(echo "scale=2; $REQUIRED_SPACE_KB / 1024 / 1024" | bc)

printf '%s\n' "[`timestamp`] Disk: ${AVAILABLE_SPACE_GB}GB free, ${REQUIRED_SPACE_GB}GB required"
if (( AVAILABLE_SPACE_KB < REQUIRED_SPACE_KB )); then
  echo "[`timestamp`] ${RED}Error:${NC} Not enough free disk space."
  exit 1
fi

# (reassemble.sh download removed; logic now in this script)

# 3. Download SHA256 file with npm-style spinner
start_spinner "Downloading SHA256 file"
curl_status_file="$MODEL_CHUNKS_DIR/.curl_status_sha256"
curl -L -w "%{http_code}" -o "$MODEL_CHUNKS_DIR/45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2.sha256" "$SHA256_URL" --silent --show-error > "$curl_status_file"
curl_status=$?
http_code=$(tail -c 3 "$curl_status_file")
rm -f "$curl_status_file" || printf '[%s] %bWarning:%b Could not remove temp status file: %s\n' "$(timestamp)" "$YELLOW" "$NC" "$curl_status_file"
if [ "$curl_status" = "0" ] && [ "$http_code" = "200" ]; then
  stop_spinner 0 "SHA256 file downloaded successfully"
else
  stop_spinner 1 "SHA256 file download failed (HTTP $http_code, curl exit $curl_status)"
  exit 1
fi

# 4. Prepare model-chunks directory
mkdir -p "$MODEL_CHUNKS_DIR"

# 5. Download all model chunk parts with a real progress bar
# (No "Downloading model chunk parts..." line; only progress bar and final tick will be shown)
printf '[%s] %bThis will take a long time as the model is 20GB big. Please be patient.%b\n' "$(timestamp)" "$YELLOW" "$NC"
printf '[%s] %bIf the download is interrupted, simply run install.sh again to resume from where it left off.%b\n' "$(timestamp)" "$BLUE" "$NC"
printf '[%s] %bResume only works as long as the machine is not rebooted (since /tmp is cleared on reboot).%b\n' "$(timestamp)" "$BLUE" "$NC"

# Progress bar function
print_progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local percent
  percent=$(awk "BEGIN {printf \"%.1f\", 100 * $current / $total}")
  local filled=$(( width * current / total ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="#"; done
  for ((i=0; i<empty; i++)); do bar+="-"; done
  printf '\r%s' "[`timestamp`] [${bar}] ${percent}%% ($current/$total)"
}

# Generate all two-letter suffixes from aa to nz (inclusive)
PARTS=()
for first in {a..n}; do
  for second in {a..z}; do
    suffix="${first}${second}"
    PARTS+=("$suffix")
    if [[ "$suffix" == "$PART_LAST" ]]; then
      break 2
    fi
  done
done

count=1
total=${#PARTS[@]}
for suffix in "${PARTS[@]}"; do
  part_file="$MODEL_CHUNKS_DIR/part_$suffix"
  url="$MODEL_CHUNKS_URL_BASE/part_$suffix"
  # Print progress bar before each file
  print_progress_bar "$count" "$total"
  if [[ "$suffix" == "$PART_LAST" ]]; then
    # For the last chunk, just check for existence
    if [[ -f "$part_file" ]]; then
      count=$((count+1))
      continue
    fi
    curl -L -C - -o "$part_file" "$url" --silent --show-error
    curl_status=$?
    if [[ "$curl_status" != "0" ]]; then
      echo -e "\n[`timestamp`] ${RED}✗${NC} Error: curl failed to download $part_file (exit $curl_status)"
      exit 1
    fi
    if [[ ! -f "$part_file" ]]; then
      echo -e "\n[`timestamp`] ${RED}✗${NC} Error: $part_file not found after download"
      exit 1
    fi
  else
    # For all other chunks, check for exactly 50MB
    if [[ -f "$part_file" ]]; then
      size=$(stat -f%z "$part_file" 2>/dev/null || stat -c%s "$part_file" 2>/dev/null)
      if [[ "$size" == "$PART_SIZE" ]]; then
        count=$((count+1))
        continue
      fi
    fi
    curl -L -C - -o "$part_file" "$url" --silent --show-error
    curl_status=$?
    if [[ "$curl_status" != "0" ]]; then
      echo -e "\n[`timestamp`] ${RED}✗${NC} Error: curl failed to download $part_file (exit $curl_status)"
      exit 1
    fi
    if [[ -f "$part_file" ]]; then
      size=$(stat -f%z "$part_file" 2>/dev/null || stat -c%s "$part_file" 2>/dev/null)
      if [[ "$size" != "$PART_SIZE" ]]; then
        echo -e "\n[`timestamp`] ${RED}✗${NC} Warning: $part_file size is $size bytes (expected $PART_SIZE)."
      fi
    else
      echo -e "\n[`timestamp`] ${RED}✗${NC} Error: $part_file not found after download"
      exit 1
    fi
  fi
  count=$((count+1))
done
# Overwrite progress bar with final success line for model chunks
bar_width=40
spaces=$(printf '%*s' $((bar_width + 30)) "")
echo -ne "\r$spaces\r"
echo -e "[`timestamp`] ${GREEN}✔${NC} Model chunks downloaded successfully"

echo
# --- Reassembly, Checksum, and Move Logic (inlined from reassemble.sh) ---

REASSEMBLED_FILE="sha256-45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2"
EXPECTED_SHA="45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2"

# Check if file already exists in target dir
if [[ -f "$TARGET_DIR/$REASSEMBLED_FILE" ]]; then
  printf '[%s] %b✔%b Model already exists at %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR/$REASSEMBLED_FILE"
  exit 0
fi

# Reassemble the file from chunks
printf '[%s] Reassembling file from chunks in %s ...\n' "$(timestamp)" "$MODEL_CHUNKS_DIR"
chunk_files=()
while IFS= read -r -d '' f; do
  chunk_files+=("$f")
done < <(find "$MODEL_CHUNKS_DIR" -type f -name "part_*" -print0 | sort -z)

if [[ ${#chunk_files[@]} -eq 0 ]]; then
  printf '[%s] %b✗%b No chunk files found in %s matching part_*\n' "$(timestamp)" "$RED" "$NC" "$MODEL_CHUNKS_DIR"
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

# Spinner for checksum
CSUM_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
csum_spinner_pid=""
csum_spinner_msg="please wait a bit while verifying checksum"
cleanup_csum_spinner() {
  if [[ -n "$csum_spinner_pid" ]]; then
    kill "$csum_spinner_pid" >/dev/null 2>&1
    wait "$csum_spinner_pid" 2>/dev/null || true
    csum_spinner_pid=""
    printf "\r\033[K"
  fi
}
trap cleanup_csum_spinner EXIT INT TERM

start_csum_spinner() {
  csum_spinner_msg="$1"
  local i=0
  (
    while :; do
      printf "\r[%s] %s %s" "$(timestamp)" "${CSUM_SPINNER_FRAMES[$i]}" "$csum_spinner_msg"
      i=$(( (i+1) % ${#CSUM_SPINNER_FRAMES[@]} ))
      sleep 0.1
    done
  ) &
  csum_spinner_pid=$!
}

stop_csum_spinner() {
  cleanup_csum_spinner
  printf "[%s] %b✔%b Checksum calculation complete\n" "$(timestamp)" "$GREEN" "$NC"
}

printf '[%s] Verifying SHA256 checksum ...\n' "$(timestamp)"
start_csum_spinner "please wait a bit while verifying checksum"
CALCULATED_SHA=$(shasum -a 256 "$REASSEMBLED_FILE" | awk '{print $1}')
stop_csum_spinner

printf '[%s] Expected SHA: %s\n' "$(timestamp)" "$EXPECTED_SHA"
printf '[%s] Calculated SHA: %s\n' "$(timestamp)" "$CALCULATED_SHA"

if [[ "$CALCULATED_SHA" != "$EXPECTED_SHA" ]]; then
  printf '[%s] %b✗%b SHA256 checksum mismatch. Removing file.\n' "$(timestamp)" "$RED" "$NC"
  rm "$REASSEMBLED_FILE"
  exit 1
else
  printf '[%s] %b✔%b Checksum verified\n' "$(timestamp)" "$GREEN" "$NC"
fi

# Move the reassembled file to the target directory
if mv "$REASSEMBLED_FILE" "$TARGET_DIR/"; then
  printf '[%s] %b✔%b File moved to %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR/$REASSEMBLED_FILE"
  # Download manifest file for Ollama registry
  mkdir -p "$MANIFEST_TARGET_DIR"
  start_spinner "Downloading manifest for phind-codellama:34b-v2"
  curl -L -o "$MANIFEST_TARGET_FILE" "$MANIFEST_URL" --silent --show-error
  curl_status=$?
  stop_spinner "$curl_status" "Manifest downloaded to $MANIFEST_TARGET_FILE"
  if [ "$curl_status" != "0" ]; then
    printf '[%s] %b✗%b Failed to download manifest file (curl exit %s)\n' "$(timestamp)" "$RED" "$NC" "$curl_status"
    exit 1
  fi
  if [ ! -s "$MANIFEST_TARGET_FILE" ]; then
    printf '[%s] %b✗%b Manifest file is empty or missing after download\n' "$(timestamp)" "$RED" "$NC"
    exit 1
  fi
  printf '[%s] %b✔%b Model setup complete! please run it using `ollama run phind-codellama:34b-v2`\n' "$(timestamp)" "$GREEN" "$NC"
  printf '[%s] %bYou may now delete the chunk files in: %s%b\n' "$(timestamp)" "$BLUE" "$MODEL_CHUNKS_DIR" "$NC"
else
  printf '[%s] %b✗%b Failed to move file to %s\n' "$(timestamp)" "$RED" "$NC" "$TARGET_DIR"
  exit 1
fi
