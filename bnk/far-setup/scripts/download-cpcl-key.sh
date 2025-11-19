#!/bin/bash
# infrastructure-modules/spk-2.1/far-setup/scripts/download-cpcl-key.sh
# Enhanced CPCL key downloader based on get-cpcl-key.sh

set -euo pipefail

# Read inputs from Terraform
eval "$(jq -r '@sh "WORK_DIR=\(.work_dir)"')"

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

CPCL_KEY_FILE="cpcl-key.yaml"
CPCL_KEY_URL="https://clouddocs.f5.com/service-proxy/latest/cpcl-key.yaml"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [download-cpcl] $*" >&2
}

# Function to handle errors
error_exit() {
    log "ERROR: $1"
    jq -nc --arg error "$1" --arg success "false" '{"success": $success, "error": $error}'
    exit 1
}

log "Starting F5 CPCL key download..."

# Download if file doesn't exist or is invalid
if [ ! -f "$CPCL_KEY_FILE" ] || ! grep -q "apiVersion.*v1" "$CPCL_KEY_FILE" 2>/dev/null; then
    log "Downloading CPCL key from F5..."
    
    # Use curl with better error handling
    if ! curl -s -L --fail --connect-timeout 30 --max-time 60 "$CPCL_KEY_URL" -o "$CPCL_KEY_FILE"; then
        error_exit "Failed to download CPCL key from $CPCL_KEY_URL. Please check your internet connection and try again."
    fi
    
    log "CPCL key downloaded successfully"
else
    log "CPCL key file already exists and appears valid: $CPCL_KEY_FILE"
fi

log "Validating CPCL key format..."

# Check if we got HTML instead of YAML (common issue)
if grep -q "<!DOCTYPE html>" "$CPCL_KEY_FILE" 2>/dev/null; then
    rm -f "$CPCL_KEY_FILE"
    error_exit "Got HTML instead of YAML file. This usually means: 1) The URL is redirecting to a login page, 2) The file has moved to a new location, 3) F5's documentation site is having issues. Manual download required from: https://clouddocs.f5.com/service-proxy/latest/spk-cwc-deploy.html"
fi

# Check for valid YAML structure
if ! grep -q "apiVersion.*v1" "$CPCL_KEY_FILE" 2>/dev/null; then
    rm -f "$CPCL_KEY_FILE"
    error_exit "Invalid CPCL key format - missing apiVersion. Expected Kubernetes ConfigMap YAML format"
fi

# Check for ConfigMap kind
if ! grep -q "kind.*ConfigMap" "$CPCL_KEY_FILE" 2>/dev/null; then
    rm -f "$CPCL_KEY_FILE"
    error_exit "Invalid CPCL key format - not a ConfigMap"
fi

# Check for required data section with JWT keys
if ! grep -q "jwt\.key" "$CPCL_KEY_FILE" 2>/dev/null; then
    rm -f "$CPCL_KEY_FILE"
    error_exit "Invalid CPCL key format - missing jwt.key data. This file doesn't contain the required JWT key data"
fi

# Check for JSON Web Key Set structure
if ! grep -q '"keys"' "$CPCL_KEY_FILE" 2>/dev/null; then
    rm -f "$CPCL_KEY_FILE"
    error_exit "Invalid CPCL key format - missing JWKS keys array"
fi

log "CPCL key validation passed successfully"

# Get file info
FILE_SIZE=$(wc -c < "$CPCL_KEY_FILE")
FILE_LINES=$(wc -l < "$CPCL_KEY_FILE")
CPCL_ABS_PATH="$(pwd)/$CPCL_KEY_FILE"

log "CPCL key file info - Size: ${FILE_SIZE} bytes, Lines: ${FILE_LINES}"
log "CPCL key ready at: $CPCL_ABS_PATH"

# Output success result for Terraform
jq -nc \
    --arg success "true" \
    --arg cpcl_file "$CPCL_ABS_PATH" \
    --arg file_size "$FILE_SIZE" \
    --arg file_lines "$FILE_LINES" \
    --arg work_dir "$(pwd)" \
    '{
        "success": $success,
        "cpcl_file": $cpcl_file,
        "file_size": $file_size,
        "file_lines": $file_lines,
        "work_dir": $work_dir
    }'

log "CPCL key download and validation completed successfully"