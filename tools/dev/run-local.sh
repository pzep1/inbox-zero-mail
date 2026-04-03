#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.build/xcode"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/InboxZeroMail.app"
APP_EXECUTABLE="${APP_PATH}/Contents/MacOS/InboxZeroMail"
DEFAULT_ENV_FILE="${ROOT_DIR}/.env.local"

ENV_FILE=""
if (($# > 0)); then
  for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == "--env-file" ]]; then
      next_index=$((i + 1))
      if ((next_index > $#)); then
        echo "Missing value for --env-file" >&2
        exit 1
      fi
      ENV_FILE="${!next_index}"
      break
    fi
  done
fi

if [[ -z "${ENV_FILE}" && -f "${DEFAULT_ENV_FILE}" ]]; then
  ENV_FILE="${DEFAULT_ENV_FILE}"
fi

load_env_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Env file not found: ${path}" >&2
    exit 1
  fi

  echo "Loading env from ${path}"
  set -a
  # shellcheck disable=SC1090
  source "${path}"
  set +a
}

if [[ -n "${ENV_FILE}" ]]; then
  load_env_file "${ENV_FILE}"
fi

USE_EMULATOR=1
AUTO_CONNECT=1
SEED_DEMO_DATA=0
BUILD_APP=1
DIRECT_LAUNCH=0
GMAIL_EMAIL="${INBOX_ZERO_GMAIL_EMULATOR_EMAIL:-alpha.inbox@example.com}"
LIVE_GMAIL_MODE=0
LIVE_GMAIL_CLIENT_ID="${INBOX_ZERO_GMAIL_CLIENT_ID:-}"
LIVE_GMAIL_CLIENT_SECRET="${INBOX_ZERO_GMAIL_CLIENT_SECRET:-}"
EXTRA_ARGS=()
GOOGLE_EMULATOR_PORT=4402
MICROSOFT_EMULATOR_PORT=4403

usage() {
  cat <<'EOF'
Usage: ./tools/dev/run-local.sh [options] [-- extra app args]

Options:
  --demo                 Run with seeded local demo data instead of the emulator
  --live-gmail           Run without the emulator and sign in with a real Gmail account
  --no-emulator          Do not start or use the local emulator
  --no-autoconnect       Do not auto-connect the seeded Gmail account
  --email <address>      Seeded Gmail emulator account to auto-connect
  --gmail-client-id <id>
                         Set INBOX_ZERO_GMAIL_CLIENT_ID for this run
  --gmail-client-secret <secret>
                         Set INBOX_ZERO_GMAIL_CLIENT_SECRET for this run
  --env-file <path>      Load shell-style env vars, defaults to ./.env.local if present
  --skip-build           Reuse the existing app build
  --direct               Launch the binary directly (passes env vars through)
  --help                 Show this help

Examples:
  ./tools/dev/run-local.sh
  ./tools/dev/run-local.sh --email beta.inbox@example.com
  ./tools/dev/run-local.sh --demo
  ./tools/dev/run-local.sh --live-gmail
EOF
}

port_is_listening() {
  local port="$1"
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
}

describe_port_listener() {
  local port="$1"
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | sed 1d || true
}

while (($# > 0)); do
  case "$1" in
    --demo)
      SEED_DEMO_DATA=1
      USE_EMULATOR=0
      AUTO_CONNECT=0
      shift
      ;;
    --live-gmail)
      LIVE_GMAIL_MODE=1
      USE_EMULATOR=0
      AUTO_CONNECT=0
      DIRECT_LAUNCH=1
      shift
      ;;
    --no-emulator)
      USE_EMULATOR=0
      shift
      ;;
    --no-autoconnect)
      AUTO_CONNECT=0
      shift
      ;;
    --email)
      if (($# < 2)); then
        echo "Missing value for --email" >&2
        exit 1
      fi
      GMAIL_EMAIL="$2"
      shift 2
      ;;
    --gmail-client-id)
      if (($# < 2)); then
        echo "Missing value for --gmail-client-id" >&2
        exit 1
      fi
      LIVE_GMAIL_MODE=1
      USE_EMULATOR=0
      AUTO_CONNECT=0
      LIVE_GMAIL_CLIENT_ID="$2"
      shift 2
      ;;
    --gmail-client-secret)
      if (($# < 2)); then
        echo "Missing value for --gmail-client-secret" >&2
        exit 1
      fi
      LIVE_GMAIL_MODE=1
      USE_EMULATOR=0
      AUTO_CONNECT=0
      LIVE_GMAIL_CLIENT_SECRET="$2"
      shift 2
      ;;
    --env-file)
      if (($# < 2)); then
        echo "Missing value for --env-file" >&2
        exit 1
      fi
      shift 2
      ;;
    --skip-build)
      BUILD_APP=0
      shift
      ;;
    --direct)
      DIRECT_LAUNCH=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

cd "${ROOT_DIR}"

if [[ "${USE_EMULATOR}" == "0" && -n "${LIVE_GMAIL_CLIENT_ID}" && "${DIRECT_LAUNCH}" == "0" ]]; then
  echo "Live Gmail credentials detected. Switching to direct launch so the app receives per-run env vars."
  DIRECT_LAUNCH=1
fi

if [[ "${LIVE_GMAIL_MODE}" == "1" && -z "${LIVE_GMAIL_CLIENT_ID}" ]]; then
  echo "Live Gmail mode requires INBOX_ZERO_GMAIL_CLIENT_ID." >&2
  echo "Set it in ${DEFAULT_ENV_FILE}, via --env-file, or with --gmail-client-id." >&2
  exit 1
fi

if [[ "${USE_EMULATOR}" == "1" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required for emulator mode." >&2
    exit 1
  fi

  google_port_in_use=0
  microsoft_port_in_use=0

  if port_is_listening "${GOOGLE_EMULATOR_PORT}"; then
    google_port_in_use=1
  fi
  if port_is_listening "${MICROSOFT_EMULATOR_PORT}"; then
    microsoft_port_in_use=1
  fi

  if [[ "${google_port_in_use}" == "1" && "${microsoft_port_in_use}" == "1" ]]; then
    echo "Emulator ports ${GOOGLE_EMULATOR_PORT} and ${MICROSOFT_EMULATOR_PORT} are already in use. Reusing the running emulator."
  elif [[ "${google_port_in_use}" == "1" || "${microsoft_port_in_use}" == "1" ]]; then
    echo "Cannot start the local emulator because only one required port is already in use." >&2
    echo "Expected both ${GOOGLE_EMULATOR_PORT} and ${MICROSOFT_EMULATOR_PORT} to be free, or both to already be serving the emulator." >&2
    if [[ "${google_port_in_use}" == "1" ]]; then
      echo "Listener on ${GOOGLE_EMULATOR_PORT}:" >&2
      describe_port_listener "${GOOGLE_EMULATOR_PORT}" >&2
    fi
    if [[ "${microsoft_port_in_use}" == "1" ]]; then
      echo "Listener on ${MICROSOFT_EMULATOR_PORT}:" >&2
      describe_port_listener "${MICROSOFT_EMULATOR_PORT}" >&2
    fi
    exit 1
  else
    echo "Starting local emulator on ports ${GOOGLE_EMULATOR_PORT} and ${MICROSOFT_EMULATOR_PORT}..."
    docker compose up -d emulate
  fi
fi

if [[ "${BUILD_APP}" == "1" ]]; then
  echo "Building InboxZeroMail..."
  xcodebuild \
    -project InboxZeroMail.xcodeproj \
    -scheme InboxZeroMail \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    build
fi

if [[ ! -x "${APP_EXECUTABLE}" ]]; then
  echo "Built app not found at ${APP_EXECUTABLE}" >&2
  exit 1
fi

APP_ARGS=()
if [[ "${USE_EMULATOR}" == "1" ]]; then
  APP_ARGS+=("--use-emulator")
fi
if [[ "${AUTO_CONNECT}" == "1" && "${USE_EMULATOR}" == "1" ]]; then
  APP_ARGS+=("--autoconnect-gmail")
  APP_ARGS+=("--gmail-emulator-email" "${GMAIL_EMAIL}")
fi
if [[ "${SEED_DEMO_DATA}" == "1" ]]; then
  APP_ARGS+=("--seed-demo-data")
fi
if ((${#EXTRA_ARGS[@]} > 0)); then
  APP_ARGS+=("${EXTRA_ARGS[@]}")
fi

echo "Launching InboxZeroMail..."
if [[ "${DIRECT_LAUNCH}" == "1" ]]; then
  if [[ -n "${LIVE_GMAIL_CLIENT_ID}" ]]; then
    export INBOX_ZERO_GMAIL_CLIENT_ID="${LIVE_GMAIL_CLIENT_ID}"
  fi
  if [[ -n "${LIVE_GMAIL_CLIENT_SECRET}" ]]; then
    export INBOX_ZERO_GMAIL_CLIENT_SECRET="${LIVE_GMAIL_CLIENT_SECRET}"
  fi
  if ((${#APP_ARGS[@]} > 0)); then
    exec "${APP_EXECUTABLE}" "${APP_ARGS[@]}"
  else
    exec "${APP_EXECUTABLE}"
  fi
else
  if ((${#APP_ARGS[@]} > 0)); then
    open -na "${APP_PATH}" --args "${APP_ARGS[@]}"
  else
    open -na "${APP_PATH}"
  fi
fi
