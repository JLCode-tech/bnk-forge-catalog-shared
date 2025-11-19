#!/bin/bash
# infrastructure-modules/spk-2.1/far-setup/scripts/download-manifest.sh
# Enhanced version of get-f5-versions.sh for Terraform external data source

set -euo pipefail

# Read inputs from Terraform
eval "$(jq -r '@sh "MANIFEST_VERSION=\(.manifest_version) WORK_DIR=\(.work_dir) CHART_NAME=\(.chart_name)"')"

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# File paths - all will be detected dynamically
MANIFEST_TAR=""
MANIFEST_DIR=""
MANIFEST_FILE=""

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [download-manifest] $*" >&2
}

# Function to handle errors
error_exit() {
    log "ERROR: $1"
    jq -nc --arg error "$1" '{"success": "false", "error": $error}'
    exit 1
}

log "Starting manifest download for version: $MANIFEST_VERSION"

# Check if FAR credentials are available (via docker config or helm registry login)
if ! command -v helm >/dev/null 2>&1; then
    error_exit "Helm is required but not installed"
fi

# Download manifest from FAR
log "Downloading manifest from FAR..."
if ! helm pull "oci://repo.f5.com/release/${CHART_NAME}" --version "$MANIFEST_VERSION" >/dev/null 2>&1; then
    error_exit "Failed to download manifest. Ensure FAR authentication is configured: helm registry login -u _json_key_base64 --password-stdin https://repo.f5.com"
fi

# Find the downloaded tar file (should be the newest .tgz file)
MANIFEST_TAR=$(ls -t *.tgz 2>/dev/null | head -n1)
if [ -z "$MANIFEST_TAR" ] || [ ! -f "$MANIFEST_TAR" ]; then
    error_exit "Could not find downloaded manifest tar file"
fi

log "Manifest downloaded successfully: $MANIFEST_TAR"

# Extract manifest if not already extracted
# Dynamically detect the extracted directory from tar contents
MANIFEST_DIR=$(tar -tf "$MANIFEST_TAR" | head -n1 | cut -d'/' -f1)
if [ -z "$MANIFEST_DIR" ]; then
    error_exit "Could not determine directory name from tar file"
fi

if [ ! -d "$MANIFEST_DIR" ]; then
    log "Extracting manifest..."
    if ! tar xf "$MANIFEST_TAR"; then
        error_exit "Failed to extract manifest archive"
    fi
    log "Manifest extracted to: $MANIFEST_DIR"
else
    log "Manifest already extracted: $MANIFEST_DIR"
fi

# Dynamically find the manifest YAML file
MANIFEST_FILE=$(find "$MANIFEST_DIR" -name "*.yaml" -type f | grep -E "(manifest|bigip)" | head -n1)
if [ -z "$MANIFEST_FILE" ]; then
    # Fallback: try any YAML file in the directory
    MANIFEST_FILE=$(find "$MANIFEST_DIR" -name "*.yaml" -type f | head -n1)
fi

# Verify manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    error_exit "Manifest YAML file not found in directory: $MANIFEST_DIR"
fi

# Validate manifest file structure
log "Validating manifest file structure..."
if ! grep -q "f5_helm_repo:" "$MANIFEST_FILE"; then
    error_exit "Invalid manifest file: missing f5_helm_repo field"
fi

if ! grep -q "helm_charts:" "$MANIFEST_FILE"; then
    error_exit "Invalid manifest file: missing helm_charts section"
fi

if ! grep -q "docker_images:" "$MANIFEST_FILE"; then
    error_exit "Invalid manifest file: missing docker_images section"
fi

# Get absolute path to manifest file
MANIFEST_ABS_PATH="$(pwd)/$MANIFEST_FILE"

log "Manifest validation successful"
log "Manifest file available at: $MANIFEST_ABS_PATH"

# Output success result for Terraform
jq -nc \
    --arg success "true" \
    --arg manifest_file "$MANIFEST_ABS_PATH" \
    --arg manifest_version "$MANIFEST_VERSION" \
    --arg work_dir "$(pwd)" \
    '{
        "success": $success,
        "manifest_file": $manifest_file,
        "manifest_version": $manifest_version,
        "work_dir": $work_dir
    }'

log "Manifest download completed successfully"