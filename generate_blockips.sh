#!/bin/bash
set -euo pipefail

app=${1}
space=${2}
org=${3}

# Target space
cf target -o ${org} -s ${space}

# Generate blockips.conf from CF env var
echo "Generating blockips.conf from cloug.gov environment variable"
APP_GUID=$(cf app "$app" --guid)
VCAP_SERVICES=$(cf curl "/v3/apps/${APP_GUID}/env" | jq -r '.system_env_json.VCAP_SERVICES')

BLOCKED_IPS=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]? 
  | select(.credentials.BLOCKED_IPS != null) 
  | .credentials.BLOCKED_IPS' | head -n 1)

if [[ -z "$BLOCKED_IPS" || "$BLOCKED_IPS" == "null" ]]; then
  echo "No BLOCKED_IPS set in cloud.gov for app '${app}', skipping blockips.conf generation"
  echo "# No blocked IPs configured" > blockips.conf
else
  echo "# Auto-generated list of blocked IPs" > blockips.conf
  IFS=',' read -ra IPS <<< "$BLOCKED_IPS"
  for ip in "${IPS[@]}"; do
    echo "if (\$http_x_forwarded_for ~* $ip) {" >> blockips.conf
    echo "    return 403;" >> blockips.conf
    echo "}" >> blockips.conf
  done
  cat blockips.conf
fi