#!/bin/bash

set -o errexit
set -o pipefail
set -x

cloud_gov=${CF_API:-https://api.fr.cloud.gov}

app=${1}
org=${2}
branch=${3}

# TODO: Remove this manual deploy
if [[ ${branch} == "develop" || ${branch} == "feature/164-set-up-circleci"]]; then
    echo "Branch is develop, deploying to dev space"
    space="dev"
else
    echo "No space detected"
    exit 1
fi

manifest=manifest_${space}.yml

if [[ -z ${org} || -z ${branch} || -z ${app} ]]; then
  echo "Usage: $0  <app> <org> <branch>" >&2
  exit 1
fi

(
  set +x # Disable debugging

  if [[ ${space} == "dev"]]; then
      # Log in if necessary
      if [[ -n ${FEC_CF_USERNAME_DEV} && -n ${FEC_CF_PASSWORD_DEV} ]]; then
        cf api ${cloud_gov}
        cf auth "${FEC_CF_USERNAME_DEV}" "${FEC_CF_PASSWORD_DEV}"
      fi
  fi
)

# TODO: Add username/pwd for other 2 spaces

# Target space
cf target -o ${org} -s ${space}

# If the app exists, use rolling deployment
if cf app ${app}; then
  command="push --strategy rolling"
else
  command="push"
fi

# Deploy web-app
cf ${command} ${app} -f ${manifest}

# Add network policy
cf add-network-policy proxy cms
