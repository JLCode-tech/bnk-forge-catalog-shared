#!/bin/bash
# infrastructure-modules/spk-2.1/far-setup/scripts/parse-versions.sh
# Enhanced version parser for SPK 2.1 manifest

set -euo pipefail

# Read inputs from Terraform
eval "$(jq -r '@sh "MANIFEST_FILE=\(.manifest_file)"')"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [parse-versions] $*" >&2
}

# Function to handle errors
error_exit() {
    log "ERROR: $1"
    jq -nc --arg error "$1" '{"error": $error}'
    exit 1
}

log "Parsing component versions from: $MANIFEST_FILE"

# Verify manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    error_exit "Manifest file not found: $MANIFEST_FILE"
fi

# Function to extract version for a helm chart
get_helm_version() {
    local chart_name="$1"
    grep -A1 "name: $chart_name" "$MANIFEST_FILE" | grep "version:" | awk '{print $2}' | head -n1
}

# Function to extract version for a docker image
get_image_version() {
    local image_name="$1"
    grep -A1 "name: $image_name" "$MANIFEST_FILE" | grep "version:" | awk '{print $2}' | head -n1
}

log "Extracting component versions..."

# Extract Helm chart versions
cert_manager=$(get_helm_version "charts/f5-cert-manager")
rabbitmq=$(get_helm_version "charts/rabbitmq")
cwc=$(get_helm_version "charts/cwc")
spk_crds_common=$(get_helm_version "charts/f5-spk-crds-common")
spk_crds_service_proxy=$(get_helm_version "charts/f5-spk-crds-service-proxy")
spk_crds_deprecated=$(get_helm_version "charts/f5-spk-crds-deprecated")
f5ingress=$(get_helm_version "charts/f5ingress")
crd_conversion=$(get_helm_version "charts/f5-crdconversion")
fluentd=$(get_helm_version "charts/f5-toda-fluentd")
dssm=$(get_helm_version "charts/f5-dssm")
observer=$(get_helm_version "charts/f5-toda-observer")
ipam_controller=$(get_helm_version "charts/f5-ipam-controller")
license_proxy=$(get_helm_version "charts/f5-license-proxy")

# Extract key Docker image versions (for reference)
tmm_img=$(get_image_version "images/tmm-img")
f5ingress_img=$(get_image_version "images/f5ingress")
spk_cwc_img=$(get_image_version "images/spk-cwc")

# Validate that critical components were found
log "Validating critical component versions..."
critical_missing=""

[ -z "$cert_manager" ] && critical_missing="$critical_missing cert_manager"
[ -z "$cwc" ] && critical_missing="$critical_missing cwc"
[ -z "$spk_crds_common" ] && critical_missing="$critical_missing spk_crds_common"
[ -z "$spk_crds_service_proxy" ] && critical_missing="$critical_missing spk_crds_service_proxy"
[ -z "$f5ingress" ] && critical_missing="$critical_missing f5ingress"

if [ -n "$critical_missing" ]; then
    error_exit "Critical component versions not found: $critical_missing"
fi

log "Version extraction completed successfully"
log "Found versions: cert_manager=$cert_manager, cwc=$cwc, f5ingress=$f5ingress"

# Output JSON for Terraform
jq -nc \
    --arg cert_manager "$cert_manager" \
    --arg rabbitmq "$rabbitmq" \
    --arg cwc "$cwc" \
    --arg spk_crds_common "$spk_crds_common" \
    --arg spk_crds_service_proxy "$spk_crds_service_proxy" \
    --arg spk_crds_deprecated "$spk_crds_deprecated" \
    --arg f5ingress "$f5ingress" \
    --arg crd_conversion "$crd_conversion" \
    --arg fluentd "$fluentd" \
    --arg dssm "$dssm" \
    --arg observer "$observer" \
    --arg ipam_controller "$ipam_controller" \
    --arg license_proxy "$license_proxy" \
    --arg tmm_img "$tmm_img" \
    --arg f5ingress_img "$f5ingress_img" \
    --arg spk_cwc_img "$spk_cwc_img" \
    '{
        "cert_manager": $cert_manager,
        "rabbitmq": $rabbitmq,
        "cwc": $cwc,
        "spk_crds_common": $spk_crds_common,
        "spk_crds_service_proxy": $spk_crds_service_proxy,
        "spk_crds_deprecated": $spk_crds_deprecated,
        "f5ingress": $f5ingress,
        "crd_conversion": $crd_conversion,
        "fluentd": $fluentd,
        "dssm": $dssm,
        "observer": $observer,
        "ipam_controller": $ipam_controller,
        "license_proxy": $license_proxy,
        "tmm_img": $tmm_img,
        "f5ingress_img": $f5ingress_img,
        "spk_cwc_img": $spk_cwc_img
    }'

log "Component versions parsed and returned successfully"