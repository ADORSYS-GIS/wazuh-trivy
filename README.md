# wazuh-trivy

[![Test install.sh](https://github.com/ADORSYS-GIS/wazuh-trivy/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/ADORSYS-GIS/wazuh-trivy/actions/workflows/test.yml)

Wazuh and Trivy integration to scan Docker image vulnerabilities.

## Install

Use the install script to download and install Trivy and configure your wazuh-agent as it should.

```bash
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/refs/heads/main/install.sh | bash
```

Edit /var/ossec/etc/shared/**_your_linux_docker_group_**/agent.conf and add the remote command:

```xml
<!-- Trivy container vulnerability scanner script -->
<wodle name="command">
  <disabled>no</disabled>
  <command>/bin/bash /var/ossec/etc/shared/trivy_scan.sh</command>
  <interval>12h</interval>
  <ignore_output>no</ignore_output>
  <run_on_start>yes</run_on_start>
  <timeout>0</timeout>
</wodle>

<localfile>
    <log_format>syslog</log_format>
    <location>/var/ossec/logs/trivy_scan.log</location>
</localfile>
```

Snyk Scan detection rules:

Create a file `custom_decoders_trity.xml` in the `/var/ossec/etc/decoders/` directory.

```xml
<decoder name="trivy-decoder">
  <prematch>^Trivy:</prematch>
</decoder>
<decoder name="trivy-decoder-fields">
  <parent>trivy-decoder</parent>
  <regex offset="after_parent">"(\.+)","(\.+)","(\.+)","(\.+)","(\.+)"</regex>
  <order>image, package, version, vulnerability_id, severity</order>
</decoder>
```

Create a file `custom_rules_trivy.xml` in the `/var/ossec/etc/rules/` directory:

```xml
<group name="trivy">
  <!-- Parent Rule for Trivy alerts -->
  <rule id="100101" level="0">
    <decoded_as>trivy-decoder</decoded_as>
    <description>Trivy alert detected.</description>
  </rule>

  <!-- This rule detects a critical severity vulnerability in a container image -->
  <rule id="100102" level="14">
    <if_sid>100101</if_sid>
    <field name="severity">Critical</field>
    <description>Trivy alert [Critical]: Vulnerabilty '$(vulnerability_id)' detected in package '$(package)' version '$(version)' on container image '$(image)'.</description>
  </rule>

  <!-- This rule detects a high severity vulnerability in a container image -->
  <rule id="100103" level="12">
    <if_sid>100101</if_sid>
    <field name="severity">High</field>
    <description>Trivy alert [High]: Vulnerabilty '$(vulnerability_id)' detected in package '$(package)' version '$(version)' on container image '$(image)'.</description>
  </rule>

  <!-- This rule detects a medium severity vulnerability in a container image -->
  <rule id="100104" level="7">
    <if_sid>100101</if_sid>
    <field name="severity">Medium</field>
    <description>Trivy alert [Medium]: Vulnerabilty '$(vulnerability_id)' detected in package '$(package)' version '$(version)' on container image '$(image)'.</description>
  </rule>

  <!-- This rule detects a low severity vulnerability in a container image -->
  <rule id="100105" level="4">
    <if_sid>100101</if_sid>
    <field name="severity">Low</field>
    <description>Trivy alert [Low]: Vulnerabilty '$(vulnerability_id)' detected in package '$(package)' version '$(version)' on container image '$(image)'.</description>
  </rule>

  <!-- This rule detects a negligible severity vulnerability in a container image -->
  <rule id="100106" level="1">
    <if_sid>100101</if_sid>
    <field name="severity">Negligible</field>
    <description>Trivy alert [Negligible]: Vulnerabilty '$(vulnerability_id)' detected in package '$(package)' version '$(version)' on container image '$(image)'.</description>
  </rule>

  <!-- This rule detects an unknown severity vulnerability in a container image -->
  <rule id="100107" level="7">
    <if_sid>100101</if_sid>
    <field name="severity">Unknown</field>
    <description>Trivy alert [Unknown]: Vulnerabilty '$(vulnerability_id)' detected in package '$(package)' version '$(version)' on container image '$(image)'.</description>
  </rule>
</group>
```

## Dashboards

### Critical vulnerabilities

1. Navigate to Explore > Discover.
2. Type rule.groups:trivy and rule.id:100102 in the filter bar and click Update. 
3. Under Available fields, add the following fields as columns by hovering on each field agent.name, data.image, data.severity, data.vulnerability_id, data.package, and data.version and clicking the + icon beside it.
4. Save the query as Trivy [Critical vulnerabilities].

### High vulnerabilities

1. Navigate to Explore > Discover.
2. Type rule.groups:trivy and rule.id:100103 in the filter bar and click Update. 
3. Under Available fields, add the following fields as columns by hovering on each field agent.name, data.image, data.severity, data.vulnerability_id, data.package, and data.version and clicking the + icon beside it.  
4. Save the query as Trivy [High vulnerabilities]. Ensure you select the Save as new search option.

### Medium vulnerabilities

1. Navigate to Explore > Discover.
2. Type rule.groups:trivy and rule.id:100104 in the filter bar and click Update. 
3. Under Available fields, add the following fields as columns by hovering on each field agent.name, data.image, data.severity, data.vulnerability_id, data.package, and data.version and clicking the + icon beside it.  
4. Save the query as Trivy [Medium vulnerabilities]. Ensure you select the Save as new search option.

### Low vulnerabilities

1. Navigate to Explore > Discover.
2. Type rule.groups:trivy and rule.id:100105 in the filter bar and click Update. 
3. Under Available fields, add the following fields as columns by hovering on each field agent.name, data.image, data.severity, data.vulnerability_id, data.package, and data.version and clicking the + icon beside it.  
4. Save the query as Trivy [Low vulnerabilities]. Ensure you select the Save as new search option. 

### Creating a custom dashboard

1. Navigate to Explore > Dashboards > Create New Dashboard.
2. Select Add an existing link and click the saved visualizations (Trivy [Critical vulnerabilities], Trivy [High vulnerabilities]. This will add the visualizations to the new dashboard.
3. Save the dashboard as Trivy container image vulnerabilities.