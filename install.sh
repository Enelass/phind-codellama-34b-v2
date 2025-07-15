#!/bin/zsh

set -e

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
REASSEMBLE_URL="https://github.com/Enelass/phind-codellama-34b-v2/raw/main/reassemble.sh"
SHA256_URL="https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/model-chunks/45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2.sha256"
MODEL_CHUNKS_URL_BASE="https://github.com/Enelass/phind-codellama-34b-v2/raw/refs/heads/main/model-chunks"
MODEL_CHUNKS_DIR="model-chunks"
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
  printf '[%s] %b✗%b Target directory not found: %s\n' "$(timestamp)" "$RED" "$NC" "$TARGET_DIR"
  printf '[%s] %bPlease make sure Ollama is installed and has been run at least once.%b\n' "$(timestamp)" "$YELLOW" "$NC"
  exit 1
else
  printf '[%s] %b✔%b Target directory found: %s\n' "$(timestamp)" "$GREEN" "$NC" "$TARGET_DIR"
fi

printf '%s\n' "[`timestamp`] Starting phind-codellama-34b-v2 model download and setup..."

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

# 2. Download reassemble.sh with npm-style spinner
start_spinner "Downloading reassemble.sh"
curl -L -o reassemble.sh "$REASSEMBLE_URL" --silent --show-error
curl_status=$?
chmod +x reassemble.sh
stop_spinner "$curl_status" "reassemble.sh downloaded successfully"
if [ "$curl_status" != "0" ]; then exit 1; fi

# 3. Download SHA256 file with npm-style spinner
start_spinner "Downloading SHA256 file"
curl -L -w "%{http_code}" -o model-chunks/45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2.sha256 "$SHA256_URL" --silent --show-error > .curl_status_sha256
curl_status=$?
http_code=$(tail -c 3 .curl_status_sha256)
rm -f .curl_status_sha256
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

# Progress bar function
print_progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local percent=$(( 100 * current / total ))
  local filled=$(( width * current / total ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="#"; done
  for ((i=0; i<empty; i++)); do bar+="-"; done
  printf '\r%s' "[`timestamp`] [${bar}] ${percent}% ($current/$total)"
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
    if [[ ! -f "$part_file" ]]; then
      echo -e "\n${RED}   -> Error: Failed to download $part_file.${NC}"
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
    if [[ -f "$part_file" ]]; then
      size=$(stat -f%z "$part_file" 2>/dev/null || stat -c%s "$part_file" 2>/dev/null)
      if [[ "$size" != "$PART_SIZE" ]]; then
        echo -e "\n${RED}   -> Warning: $part_file size is $size bytes (expected $PART_SIZE).${NC}"
      fi
    else
      echo -e "\n${RED}   -> Error: Failed to download $part_file.${NC}"
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
source ./reassemble.sh
