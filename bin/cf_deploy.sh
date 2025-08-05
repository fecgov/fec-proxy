#!/bin/bash

set -o errexit
set -o pipefail
set -x

cloud_gov=${CF_API:-https://api.fr.cloud.gov}

app=${1}
org=${2}
branch=${3}

# Get the space that corresponds with the branch name
if [[ ${branch} == "test-dev-ip-block" ]]; then
    echo "Branch is develop, deploying to dev space"
    space="dev"
elif [[ ${branch} == release* ]]; then
    echo "Branch starts with release, deploying to stage space"
    space="stage"
elif [[ ${branch} == "master" ]]; then
    echo "Branch is master, deploying to prod space"
    space="prod"
else
# Don't deploy other branches, pass build
    echo "No space detected"
    exit 0
fi

manifest=manifest_${space}.yml

# Get username/password for relevant space (uppercased)
cf_username_label="FEC_CF_USERNAME_$(echo $space | tr [a-z] [A-Z])"
cf_password_label="FEC_CF_PASSWORD_$(echo $space | tr [a-z] [A-Z])"

if [[ -z ${org} || -z ${branch} || -z ${app} ]]; then
  echo "Usage: $0  <app> <org> <branch>" >&2
  exit 1
fi

(
  set +x # Disable debugging

  if [[ -n ${!cf_username_label} && -n ${!cf_password_label} ]]; then
    cf api ${cloud_gov}
    cf auth "${!cf_username_label}" "${!cf_password_label}"
  fi
)

# Call blocklist generator before deploy
./generate_blockips.sh "${app}" "${space}" "${org}"

# If the app exists, use rolling deployment
if cf app ${app}; then
  command="push --strategy rolling"
else
  command="push"
fi

# Deploy app
cf ${command} ${app} -f ${manifest}

# Add network policies
cf add-network-policy proxy cms
