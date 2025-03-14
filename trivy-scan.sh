#!/bin/bash
# Copyright (C) 2025, ADORSYS GmbH & CO KG.

# Directory to save the custom output template
TEMPLATE_FILE="/tmp/trivy-custom.tmpl"

# Monitored log file for Wazuh
LOG_FILE="/var/ossec/logs/trivy-scan.log"

cleanup() {
    # Remove temporary file
    if [ -f "$TEMPLATE_FILE" ]; then
        rm -f "$TEMPLATE_FILE"
    fi
}

trap cleanup EXIT

# Create the custom output template
cat <<EOL > "$TEMPLATE_FILE"
"Package","Version Installed","Vulnerability ID","Severity"
{{- range \$ri, \$r := . }}
{{- range \$vi, \$v := .Vulnerabilities }}
"{{ $v.PkgName }}","{{$v.InstalledVersion }}","{{ $v.VulnerabilityID }}","{{$v.Severity}}"
{{- end}}
{{- end }}
EOL

# Function to detect the available container engine
detect_container_engine() {
    if command -v docker &> /dev/null; then
        echo "docker"
    elif command -v podman &> /dev/null; then
        echo "podman"
    elif command -v ctr &> /dev/null; then
        echo "containerd"
    else
        echo "No supported container engine found. Please install Docker, Podman, or containerd."
        exit 1
    fi
}

# Retrieve the container engine
CONTAINER_ENGINE=$(detect_container_engine)

# Retrieve list of container images
if [ "$CONTAINER_ENGINE" == "docker" ]; then
    images=$(docker images --format "{{.Repository}}:{{.Tag}}")
elif [ "$CONTAINER_ENGINE" == "podman" ]; then
    images=$(podman images --format "{{.Repository}}:{{.Tag}}")
elif [ "$CONTAINER_ENGINE" == "containerd" ]; then
    images=$(ctr -n k8s.io images list -q)
else
    echo "Unsupported container engine: $CONTAINER_ENGINE"
    exit 1
fi

if [ -z "$images" ]; then
  echo "Trivy: No images found. Exiting..." >> "$LOG_FILE"
  exit 1
fi

# Loop through each container image and run Trivy scan
for image in $images; do
    # Run Trivy scan on the current image using the custom output template
    trivy_output=$(trivy -q --scanners vuln i --format template --template '@/tmp/trivy-custom.tmpl' $image)

    # Process Trivy output for the current image
    while IFS= read -r line; do
        # Prepend image name with quotes and comma, and add timestamp
        formatted_line="Trivy:\"$image\",$line"

        # Write the formatted line to the monitored log file
        echo "$formatted_line" >> "$LOG_FILE"
    done <<< "$trivy_output"
done
