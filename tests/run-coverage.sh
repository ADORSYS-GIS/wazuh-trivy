#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$REPO_ROOT/coverage}"

mkdir -p "$OUTPUT_DIR"
cd "$REPO_ROOT"

echo "==> Running Bats unit tests under kcov..."
kcov --include-pattern=scripts/ "$OUTPUT_DIR/kcov" bats tests/test-utils.bats tests/test-scripts.bats

echo "==> Merging SonarQube XML coverage reports..."
python3 - "$OUTPUT_DIR" << 'EOF'
import xml.etree.ElementTree as ET
import glob
import os
import sys

output_dir = sys.argv[1]
kcov_dir = os.path.join(output_dir, "kcov")
xml_files = glob.glob(os.path.join(kcov_dir, "**/sonarqube.xml"), recursive=True)

if not xml_files:
    sys.exit(f"Error: No sonarqube.xml found under {kcov_dir}")

merged_files = {}

for xml_file in xml_files:
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        for f in root.findall("file"):
            raw_path = f.get("path", "")
            if "scripts/" in raw_path:
                norm_path = "scripts/" + raw_path.split("scripts/", 1)[1]
            else:
                norm_path = raw_path

            if norm_path not in merged_files:
                merged_files[norm_path] = {}

            for line in f.findall("lineToCover"):
                num = int(line.get("lineNumber"))
                is_cov = line.get("covered") == "true"
                merged_files[norm_path][num] = merged_files[norm_path].get(num, False) or is_cov
    except Exception as e:
        print(f"Warning: Failed to parse {xml_file}: {e}", file=sys.stderr)

merged_root = ET.Element("coverage", version="1")
for f_path in sorted(merged_files.keys()):
    f_elem = ET.SubElement(merged_root, "file", path=f_path)
    for line_num in sorted(merged_files[f_path].keys()):
        cov_str = "true" if merged_files[f_path][line_num] else "false"
        ET.SubElement(f_elem, "lineToCover", lineNumber=str(line_num), covered=cov_str)

target_path = os.path.join(output_dir, "sonar-coverage.xml")
merged_tree = ET.ElementTree(merged_root)
merged_tree.write(target_path, encoding="utf-8", xml_declaration=True)
print(f"==> Successfully merged {len(xml_files)} report(s) covering {len(merged_files)} file(s) into {target_path}")
EOF
