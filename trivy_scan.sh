#!/bin/bash
# Copyright (C) 2024, DevOpsTales.

# Directory to save the custom output template
TEMPLATE_FILE="/tmp/tsv.tpl"

# Create the custom output template (unchanged)
cat <<EOL > "$TEMPLATE_FILE"
"Package","Version Installed","Vulnerability ID","Severity"
{{- range \$ri, \$r := . }}
{{- range \$vi, \$v := .Vulnerabilities }}
"{{ $v.PkgName }}","{{$v.InstalledVersion }}","{{ $v.VulnerabilityID }}","{{$v.Severity}}"
{{- end}}
{{- end }}
EOL

# Retrieve list of container images
images=$(docker images --format "{{.Repository}}:{{.Tag}}")

# Loop through each container image and run Trivy scan
for image in $images; do
  # Run Trivy scan on the current image using the custom output template
  trivy_output=$(trivy -q --scanners vuln i --format template --template '@/tmp/tsv.tpl' $image)

  # Process Trivy output for the current image
  while IFS= read -r line; do
        # Prepend image name with quotes and comma
        formatted_line=Trivy:"\"$image\","$line
        # Print the formatted line with quoted image name
        echo "$formatted_line"
  done <<< "$trivy_output"
done

# Clean up the custom output template
#rm -f "$TEMPLATE_FILE"
