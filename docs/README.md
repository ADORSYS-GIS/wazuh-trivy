# wazuh-trivy Documentation

This is the central documentation hub for the `wazuh-trivy` project. It maps the software development lifecycle (SDLC) to the documentation in this repository and provides quick links to the key operational and architectural references.

## Project Summary

`wazuh-trivy` integrates the [Trivy](https://trivy.dev/) container image vulnerability scanner with the [Wazuh](https://wazuh.com/) security platform. It scans container images (Docker, Podman, containerd) for known vulnerabilities and writes the results to a log file that the Wazuh agent can read, so container image vulnerabilities are visible in the Wazuh SIEM.

## SDLC Map

| Phase | Directory | Purpose |
| :--- | :--- | :--- |
| Architecture | [`docs/architecture/overview.md`](./architecture/overview.md) | How Trivy scans images and how results flow into Wazuh |
| Operations | [`docs/operations/installation.md`](./operations/installation.md) | Multi-platform installation, configuration, and service control |
| Testing | [`tests/`](../tests/) | Bats tests for the install scripts |
| Configuration | [`config/`](../config/) | Wazuh decoders and rules for Trivy alerts |

## Quick Links

| Topic | Link |
| :--- | :--- |
| System architecture and data flow | [Architecture overview](./architecture/overview.md) |
| Installation (Linux / macOS) | [Installation guide](./operations/installation.md) |
| Root README | [README](../README.md) |

## Documentation Standard

All documentation in this repository follows the organization-wide documentation standard defined in [`ADORSYS-GIS/wazuh/docs/DOCS-STANDARD.md`](https://github.com/ADORSYS-GIS/wazuh/blob/main/docs/DOCS-STANDARD.md).
