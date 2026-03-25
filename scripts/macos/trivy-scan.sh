#!/bin/bash
# macOS-specific trivy scan logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
. "$SCRIPT_DIR/../common.sh"

LOG_FILE="/Library/Ossec/logs/trivy-scan.log"
TEMPLATE_FILE="/tmp/trivy-custom.tmpl"

run_scan() {
    local CONTAINER_ENGINE
    CONTAINER_ENGINE=$(detect_container_engine)

    cat <<'EOL' > "$TEMPLATE_FILE"
"Package","Version Installed","Vulnerability ID","Severity"
{{- range $ri, $r := . }}
{{- range $vi, $v := .Vulnerabilities }}
"{{ $v.PkgName }}","{{$v.InstalledVersion }}","{{ $v.VulnerabilityID }}","{{$v.Severity}}"
{{- end}}
{{- end }}
EOL

    local images=""
    if [ "$CONTAINER_ENGINE" = "docker" ]; then
        images=$(docker images --format "{{.Repository}}:{{.Tag}}")
    elif [ "$CONTAINER_ENGINE" = "podman" ]; then
        images=$(podman images --format "{{.Repository}}:{{.Tag}}")
    elif [ "$CONTAINER_ENGINE" = "containerd" ]; then
        images=$(
            sudo ctr namespaces list -q 2>/dev/null | while read -r ns; do
                sudo ctr -n "$ns" images list -q 2>/dev/null
            done | sort -u
        )
    fi

    if [ -z "$images" ]; then
        echo "Trivy: No images found. Exiting..." >> "$LOG_FILE"
        exit 1
    fi

    for image in $images; do
        local trivy_output
        trivy_output=$(trivy -q --scanners vuln i --format template --template "@$TEMPLATE_FILE" "$image")
        while IFS= read -r line; do
            echo "Trivy:\"$image\",$line" >> "$LOG_FILE"
        done <<< "$trivy_output"
    done
}
