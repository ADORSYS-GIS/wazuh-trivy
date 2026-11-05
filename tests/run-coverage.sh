#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$REPO_ROOT/coverage}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cd "$REPO_ROOT"

echo "==> Running Bats unit tests under kcov..."
kcov --include-pattern="$REPO_ROOT/scripts/" "$OUTPUT_DIR/kcov" bats tests/test-utils.bats tests/test-scripts.bats

# kcov natively generates sonarqube.xml for test runs
XML_FILES=($(find "$OUTPUT_DIR/kcov" -name "sonarqube.xml"))
if [[ ${#XML_FILES[@]} -eq 0 ]]; then
    echo "Error: kcov did not generate sonarqube.xml" >&2
    exit 1
elif [[ ${#XML_FILES[@]} -gt 1 ]]; then
    echo "==> Merging multiple coverage reports using kcov built-in merge..."
    kcov --merge "$OUTPUT_DIR/kcov-merged" "$OUTPUT_DIR/kcov"/*
    SONAR_XML="$OUTPUT_DIR/kcov-merged/sonarqube.xml"
else
    SONAR_XML="${XML_FILES[0]}"
fi

# Normalize paths for SonarQube generic coverage reporting
cp "$SONAR_XML" "$OUTPUT_DIR/sonar-coverage.xml"
sed -i "s|path=\"$REPO_ROOT/|path=\"|g" "$OUTPUT_DIR/sonar-coverage.xml"
sed -i 's|path=".*scripts/|path="scripts/|g' "$OUTPUT_DIR/sonar-coverage.xml"

echo "==> SonarQube coverage report successfully generated at $OUTPUT_DIR/sonar-coverage.xml"
