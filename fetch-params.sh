#!/usr/bin/env bash
set -eo pipefail

usage () {
  cat << EOF
Usage: fetch-params.sh [options] environment

environments:
 mainnet
 preprod
 preview
 all

Options:
  -p, --project-id string   Blockfrost API key (overrides BLOCKFROST_PROJECT_ID environment variable)
  -h, --help                Show this help text
}
EOF
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

if [[ -z "${PROJECT_ID}" && -n "${BLOCKFROST_PROJECT_ID}" ]]; then
  PROJECT_ID="${BLOCKFROST_PROJECT_ID}"
fi

if [[ -z "${PROJECT_ID}" ]]; then
  cat << EOF >&2
Missing Blockfrost API key! \
Use the BLOCKCHAID_PROJECT_ID environment variable or --project-id option to specify it.
EOF

  exit 2
fi

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
