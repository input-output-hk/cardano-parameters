#!/usr/bin/env bash
set -eo pipefail

usage () {
  cat << EOF
Usage: fetch-params.sh [options] environment

environments:
 mainnet
 preprod
 preview

Options:
  -p, --project-id string   Blockfrost API key (overrides BLOCKFROST_PROJECT_ID environment variable)
  -h, --help                Show this help text
}
EOF
}

lookup_project_id () {
  local env="$(echo ${ENV} | tr '[:lower:]' '[:upper:]')"
  local env_key="BLOCKFROST_PROJECT_ID_${env}"
  BLOCKFROST_PROJECT_ID_NETWORK="${!env_key}"

  if [[ -n "${PROJECT_ID}" ]]; then
    echo "${PROJECT_ID}"
  elif [[ -n "${BLOCKFROST_PROJECT_ID_NETWORK}" ]]; then
    echo "${BLOCKFROST_PROJECT_ID_NETWORK}"
  elif [[ -n "${BLOCKFROST_PROJECT_ID}" ]]; then
    echo "${BLOCKFROST_PROJECT_ID}"
  else
    cat << EOF >&2
Missing Blockfrost API key! \
Use the BLOCKFROST_PROJECT_ID/BLOCKFROST_PROJECT_ID_<NETWORK> environment variables or --project-id option to specify it.
EOF

    exit 2
  fi
}

# Parse command line arguments
if ! OPTS=$(getopt -o p:h --long project-id:,help -n "fetch-cardano-cfg.sh" -- "$@"); then
  exit 1
fi

eval set -- "${OPTS}"

while true; do
  case "$1" in
    -p | --project-id)
      PROJECT_ID=$2
      shift 2
      ;;
    -h | --help)
      HELP=
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Internal error!" >&2
      exit 1
      ;;
  esac
done

# Validate command line arguments
if [[ "${HELP+DEFINED}" = true ]]; then
  usage
  exit 1
fi

if [[ "$#" -eq 0 ||  -z "$1" ]]; then
  echo "Missing required argument environment!" >&2
  exit 1
else
  ENV=$1
fi

PROJECT_ID="$(lookup_project_id)"

# Calculate endpoint
case "${ENV}" in
  mainnet)
    BLOCKFROST_HOST=cardano-mainnet.blockfrost.io
    ;;
  preprod)
    BLOCKFROST_HOST=cardano-preprod.blockfrost.io
    ;;
  preview)
    BLOCKFROST_HOST=cardano-preview.blockfrost.io
    ;;
  *)
    echo "Invalid environment: '${ENV}'" >&2
esac

tmpfile=$(mktemp --tmpdir "parameters.XXXXXX")

# Do the request
curl \
  -H "project_id: ${PROJECT_ID}" \
  --no-progress-meter \
  --fail \
  "https://${BLOCKFROST_HOST}/api/v0/epochs/latest/parameters" \
  | jq --sort-keys . \
  > "${tmpfile}"

mkdir -p "${ENV}"
mv "${tmpfile}" "${ENV}/parameters.json"
