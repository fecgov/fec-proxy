#!/bin/bash
set -euo pipefail

app=${1}
space=${2}
org=${3}

# Target space
cf target -o ${org} -s ${space}

# Generate blockips.conf from CF env var
echo "Generating blockips.conf from Cloud Foundry environment variable..."
APP_GUID=$(cf app "$app" --guid)
BLOCKED_IPS=$(cf curl "/v3/apps/${APP_GUID}/environment_variables" | jq -r '.var.BLOCKED_IPS')

if [[ -z "$BLOCKED_IPS" || "$BLOCKED_IPS" == "null" ]]; then
  echo "No BLOCKED_IPS set in Cloud Foundry for app '${app}', skipping blockips.conf generation"
  echo "# No blocked IPs configured" > blockips.conf
else
  echo "# Auto-generated list of blocked IPs" > blockips.conf
  IFS=',' read -ra IPS <<< "$BLOCKED_IPS"
  for ip in "${IPS[@]}"; do
    echo "if (\$http_x_forwarded_for ~* $ip) {" >> blockips.conf
    echo "    return 403;" >> blockips.conf
    echo "}" >> blockips.conf
  done
  echo "blockips.conf generated with ${#IPS[@]} IPs"
  cat blockips.conf
fi