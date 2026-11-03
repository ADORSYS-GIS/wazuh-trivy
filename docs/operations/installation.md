# wazuh-trivy Installation Guide

This guide covers installing and configuring `wazuh-trivy` on Linux and macOS. The install scripts download and install Trivy, deploy the scan script, and configure the Wazuh agent to collect and alert on the scan results.

## Prerequisites

- A running **Wazuh agent** on the target host.
- A **container engine** on the target host: Docker, Podman, or containerd. Trivy cannot scan without one.
- `curl` and `sudo` access.

## Linux

### Install

Run the Linux install script:

```bash
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/refs/heads/main/scripts/linux/install.sh | sudo bash
```

The script performs the following:

1. Verifies the OS is Linux.
2. Downloads and verifies the shared utilities (`scripts/shared/utils.sh`) against `checksums.sha256`.
3. Checks that a container engine (Docker, Podman, or containerd) is present.
4. Installs Trivy (default version `0.69.2`) to `/usr/bin`.
5. Deploys `trivy-scan.sh` to `/var/ossec/wodles/trivy-scan.sh`.
6. Enables Wazuh remote commands (`wazuh_command.remote_commands=1`).
7. Creates the log file `/var/ossec/logs/trivy-scan.log`.

### Configure the Wazuh agent

On the Wazuh manager, edit the centralized agent configuration `/var/ossec/etc/shared/<your_linux_docker_group>/agent.conf` (this file is distributed to the agents in that group) and add the wodle command and log collector:

```xml
<!-- Trivy container vulnerability scanner script -->
<wodle name="command">
  <disabled>no</disabled>
  <command>/bin/bash /var/ossec/wodles/trivy-scan.sh</command>
  <interval>12h</interval>
  <ignore_output>no</ignore_output>
  <run_on_start>yes</run_on_start>
  <timeout>0</timeout>
</wodle>

<localfile>
    <log_format>syslog</log_format>
    <location>/var/ossec/logs/trivy-scan.log</location>
</localfile>
```

### Add the decoder and rules

Decoding and rule matching happen on the **Wazuh manager**, not the agent. Copy the decoder and rules to the manager's `/var/ossec/etc/decoders/` and `/var/ossec/etc/rules/` directories. The commands below assume you are running them from the repository root:

```bash
sudo cp config/custom_decoders_trity.xml /var/ossec/etc/decoders/
sudo cp config/custom_rules_trivy.xml /var/ossec/etc/rules/
```

Restart the Wazuh manager to load the new decoder and rules:

```bash
sudo systemctl restart wazuh-manager
```

### Verify

Confirm the scan log is being written:

```bash
sudo tail -f /var/ossec/logs/trivy-scan.log
```

Confirm the agent is collecting the log:

```bash
sudo /var/ossec/bin/wazuh-control status
```

### Uninstall

Run the Linux uninstall script:

```bash
sudo bash scripts/linux/uninstall.sh
```

## macOS

### Install

Run the macOS install script:

```bash
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/refs/heads/main/scripts/macos/install.sh | sudo bash
```

The script follows the same steps as Linux but uses the macOS paths:

- Scan script: `/Library/Ossec/wodles/trivy-scan.sh`
- Log file: `/Library/Ossec/logs/trivy-scan.log`

### Configure the Wazuh agent

Add the wodle command and log collector to the agent configuration, pointing at the macOS log path:

```xml
<wodle name="command">
  <disabled>no</disabled>
  <command>/bin/bash /Library/Ossec/wodles/trivy-scan.sh</command>
  <interval>12h</interval>
  <ignore_output>no</ignore_output>
  <run_on_start>yes</run_on_start>
  <timeout>0</timeout>
</wodle>

<localfile>
    <log_format>syslog</log_format>
    <location>/Library/Ossec/logs/trivy-scan.log</location>
</localfile>
```

### Uninstall

Run the macOS uninstall script:

```bash
sudo bash scripts/macos/uninstall.sh
```

## Container Engine Support

The scan script auto-detects the container engine:

| Engine | Detection |
| :--- | :--- |
| Docker | `docker images` |
| Podman | `podman images` |
| containerd | `ctr` namespaces and images |

## Configuration Reference

| Setting | Default | Description |
| :--- | :--- | :--- |
| `TRIVY_VERSION` | `0.69.2` | Trivy version to install |
| `OSSEC_WODLES_DIR` | `/var/ossec/wodles` (Linux) / `/Library/Ossec/wodles` (macOS) | Scan script directory |
| `OSSEC_LOG_DIR` | `/var/ossec/logs` (Linux) / `/Library/Ossec/logs` (macOS) | Log directory |
| `TRIVY_SCAN_LOG_PATH` | `$OSSEC_LOG_DIR/trivy-scan.log` | Scan log file |
