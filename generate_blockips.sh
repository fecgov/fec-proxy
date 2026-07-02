#!/bin/bash
set -euo pipefail

app=${1}
space=${2}
org=${3}

# Target space
cf target -o ${org} -s ${space}

echo "Generating blockips.conf from cloud.gov environment variable"
APP_GUID=$(cf app "$app" --guid)
VCAP_SERVICES=$(cf curl "/v3/apps/${APP_GUID}/env" | jq -r '.system_env_json.VCAP_SERVICES')

BLOCKED_IPS=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]? 
  | select(.credentials.BLOCKED_IPS != null) 
  | .credentials.BLOCKED_IPS' | head -n 1)

RATE_LIMITED_IPS=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.RATE_LIMITED_IPS != null)
  | .credentials.RATE_LIMITED_IPS' | head -n 1)

RATE_LIMITED_ROUTES=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.RATE_LIMITED_ROUTES != null)
  | .credentials.RATE_LIMITED_ROUTES' | head -n 1)

KEEPALIVE_TIMEOUT=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.KEEPALIVE_TIMEOUT != null)
  | .credentials.KEEPALIVE_TIMEOUT' | head -n 1)

PROXY_CONNECT_TIMEOUT=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.PROXY_CONNECT_TIMEOUT != null)
  | .credentials.PROXY_CONNECT_TIMEOUT' | head -n 1)

PROXY_READ_TIMEOUT=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.PROXY_READ_TIMEOUT != null)
  | .credentials.PROXY_READ_TIMEOUT' | head -n 1)

RATE_LIMIT_RATE=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.RATE_LIMIT_RATE != null)
  | .credentials.RATE_LIMIT_RATE' | head -n 1)

RATE_LIMIT_BURST=$(echo "$VCAP_SERVICES" | jq -r '
  .["user-provided"][]?
  | select(.credentials.RATE_LIMIT_BURST != null)
  | .credentials.RATE_LIMIT_BURST' | head -n 1)

if [[ -z "$BLOCKED_IPS" || "$BLOCKED_IPS" == "null" ]]; then
  echo "No BLOCKED_IPS set in cloud.gov for app '${app}', skipping blockips.conf generation"
  echo "# No blocked IPs configured" > blockips.conf
else
  echo "# Auto-generated list of blocked IPs" > blockips.conf
  IFS=',' read -ra IPS <<< "$BLOCKED_IPS"
  for ip in "${IPS[@]}"; do
    ip=$(echo "$ip" | xargs)
    [[ -z "$ip" ]] && continue
    escaped_ip=$(echo "$ip" | sed 's/\./\\./g')
    echo "if (\$http_x_forwarded_for ~* ${escaped_ip}) {" >> blockips.conf
    echo "    return 403;" >> blockips.conf
    echo "}" >> blockips.conf
  done
fi

if [[ -z "$RATE_LIMITED_IPS" || "$RATE_LIMITED_IPS" == "null" ]]; then
  echo "No RATE_LIMITED_IPS set in cloud.gov for app '${app}', skipping ratelimitedips.conf generation"
  echo "# No rate-limited IPs configured" > ratelimitedips.conf
else
  echo "# Auto-generated list of rate-limited IPs" > ratelimitedips.conf
  IFS=',' read -ra IPS <<< "$RATE_LIMITED_IPS"
  for ip in "${IPS[@]}"; do
    ip=$(echo "$ip" | xargs)
    [[ -z "$ip" ]] && continue
    echo "$ip 1;" >> ratelimitedips.conf
  done
fi

if [[ -z "$RATE_LIMITED_ROUTES" || "$RATE_LIMITED_ROUTES" == "null" ]]; then
  echo "No RATE_LIMITED_ROUTES set in cloud.gov for app '${app}', skipping ratelimitedroutes.conf generation"
  echo "# No rate-limited routes configured" > ratelimitedroutes.conf
else
  echo "# Auto-generated list of rate-limited routes" > ratelimitedroutes.conf
  IFS=',' read -ra ROUTES <<< "$RATE_LIMITED_ROUTES"
  for route in "${ROUTES[@]}"; do
    route=$(echo "$route" | xargs)
    [[ -z "$route" ]] && continue
    echo "~^1:${route} \$client_ip;" >> ratelimitedroutes.conf
  done
fi

KEEPALIVE_TIMEOUT=${KEEPALIVE_TIMEOUT:-90}
PROXY_CONNECT_TIMEOUT=${PROXY_CONNECT_TIMEOUT:-90}
PROXY_READ_TIMEOUT=${PROXY_READ_TIMEOUT:-90}
RATE_LIMIT_RATE=${RATE_LIMIT_RATE:-10r/m}
RATE_LIMIT_BURST=${RATE_LIMIT_BURST:-10}

[[ "$KEEPALIVE_TIMEOUT" == "null" ]] && KEEPALIVE_TIMEOUT=90
[[ "$PROXY_CONNECT_TIMEOUT" == "null" ]] && PROXY_CONNECT_TIMEOUT=90
[[ "$PROXY_READ_TIMEOUT" == "null" ]] && PROXY_READ_TIMEOUT=90
[[ "$RATE_LIMIT_RATE" == "null" ]] && RATE_LIMIT_RATE=10r/m
[[ "$RATE_LIMIT_BURST" == "null" ]] && RATE_LIMIT_BURST=10

KEEPALIVE_TIMEOUT=$(echo "$KEEPALIVE_TIMEOUT" | xargs)
PROXY_CONNECT_TIMEOUT=$(echo "$PROXY_CONNECT_TIMEOUT" | xargs)
PROXY_READ_TIMEOUT=$(echo "$PROXY_READ_TIMEOUT" | xargs)
RATE_LIMIT_RATE=$(echo "$RATE_LIMIT_RATE" | xargs)
RATE_LIMIT_BURST=$(echo "$RATE_LIMIT_BURST" | xargs)

echo "Generating proxysettings.conf from cloud.gov environment variable"
{
  echo "# Auto-generated proxy settings"
  echo "keepalive_timeout ${KEEPALIVE_TIMEOUT};"
  echo "proxy_connect_timeout ${PROXY_CONNECT_TIMEOUT};"
  echo "proxy_read_timeout ${PROXY_READ_TIMEOUT};"
  echo "limit_req_zone \$limited_route_key zone=limited_routes_by_client:5m rate=${RATE_LIMIT_RATE};"
  if [[ "$RATE_LIMIT_BURST" == "0" ]]; then
    echo "limit_req zone=limited_routes_by_client;"
  else
    echo "limit_req zone=limited_routes_by_client burst=${RATE_LIMIT_BURST} nodelay;"
  fi
} > proxysettings.conf
