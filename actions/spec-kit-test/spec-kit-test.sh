#!/usr/bin/env bash
# mz: spec-kit — run ZAgents Executable Spec Kit tests in any CI (GitHub
# Actions, GitLab CI, Jenkins, plain bash) and report results to ZAgents.
#
#   curl -fsSL https://raw.githubusercontent.com/ZurabDev/zagents-releases/main/scripts/spec-kit-test.sh \
#     | bash -s -- --gate deploy --project "Pricing 2.0"
#
# Every argument is passed to `zagents spec test run` (see `--help`).
# The script exits with the CLI's exit code (0 ok, 1 gated failure,
# 2 usage/config, 3 nothing to run with --require-tests, 10 Spec Kit off).
set -euo pipefail

RELEASES_URL="${ZAGENTS_RELEASES_URL:-https://github.com/ZurabDev/zagents-releases}"

usage() {
  cat <<'EOF'
Usage: spec-kit-test.sh [zagents spec test run flags...]
       spec-kit-test.sh drift --since <sha> [zagents spec drift flags...]

Runs `zagents spec test run` in the current checkout and reports the results
to ZAgents. Installs the zagents CLI first when it is not on PATH. With
"drift" first it runs `zagents spec drift` instead (read only).

Environment:
  ZAGENTS_TOKEN         Workspace API token (required; a CI secret)
  ZAGENTS_SERVER_URL    ZAgents server (default https://zagents.cnt.me)
  ZAGENTS_WORKSPACE_ID  Workspace id (when the token is not bound to one)
  ZAGENTS_CLI_VERSION   CLI version to install, e.g. 0.7.0-mz.1 (default latest)
  ZAGENTS_BIN_DIR       Where to install the CLI (default $HOME/.local/bin)
  ZAGENTS_CLI           Use this zagents binary instead of PATH / install

Common flags (all flags: zagents spec test run --help):
  --project <p> --component <d.c> --spec <SPEC-n> --issue <KEY>
  --gate deploy|pr|nightly|manual|all   --tag <t> (repeat)
  --parallel N  --junit-dir DIR  --fail-on deploy|pr|any  --dry-run

Examples:
  # Deploy gate in GitLab CI / Jenkins
  ZAGENTS_TOKEN=$TOKEN bash spec-kit-test.sh --gate deploy --project "Pricing 2.0"

  # Straight from the public releases repo
  curl -fsSL https://raw.githubusercontent.com/ZurabDev/zagents-releases/main/scripts/spec-kit-test.sh \
    | bash -s -- --gate pr --project "Pricing 2.0"
EOF
}

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'spec-kit-test: %s\n' "$*" >&2; exit 2; }

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done

detect_platform() {
  case "$(uname -s)" in
    Linux) OS=linux ;;
    Darwin) OS=darwin ;;
    *) die "unsupported OS $(uname -s); install the zagents CLI yourself and set ZAGENTS_CLI" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) die "unsupported architecture $(uname -m)" ;;
  esac
}

# Same release assets as scripts/install.sh (zagents-cli-<v>-<os>-<arch>.tar.gz
# in the public releases repo), installed without sudo into ZAGENTS_BIN_DIR.
install_cli() {
  detect_platform
  local version="${ZAGENTS_CLI_VERSION:-}"
  if [ -z "$version" ]; then
    local tag
    tag=$(curl -fsSI --retry 3 --retry-delay 2 "$RELEASES_URL/releases/latest" 2>/dev/null | grep -i '^location:' | sed 's/.*tag\///' | tr -d '\r\n' || true)
    [ -n "$tag" ] || die "could not determine the latest zagents release from $RELEASES_URL"
    version="${tag#v}"
  fi
  version="${version#v}"
  local bin_dir="${ZAGENTS_BIN_DIR:-$HOME/.local/bin}"
  local asset="zagents-cli-${version}-${OS}-${ARCH}.tar.gz"
  local base="$RELEASES_URL/releases/download/v${version}"
  local tmp
  tmp=$(mktemp -d)
  log "Installing zagents ${version} (${OS}/${ARCH}) into ${bin_dir}"
  curl -fsSL --retry 3 --retry-delay 2 "$base/$asset" -o "$tmp/$asset" || die "download failed: $base/$asset"
  # Fail closed: no checksums.txt or no line for the asset means no install.
  curl -fsSL --retry 3 --retry-delay 2 "$base/checksums.txt" -o "$tmp/checksums.txt" ||
    die "download failed: $base/checksums.txt (refusing to install an unverified CLI)"
  local want got
  want=$(awk -v a="$asset" '$2 == a || $2 == "*" a {print $1}' "$tmp/checksums.txt")
  [ -n "$want" ] || die "checksums.txt has no entry for $asset (refusing to install an unverified CLI)"
  if command -v sha256sum >/dev/null 2>&1; then
    got=$(sha256sum "$tmp/$asset" | awk '{print $1}')
  else
    got=$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')
  fi
  [ "$want" = "$got" ] || die "checksum mismatch for $asset"
  tar -xzf "$tmp/$asset" -C "$tmp" zagents
  mkdir -p "$bin_dir"
  mv "$tmp/zagents" "$bin_dir/zagents"
  chmod +x "$bin_dir/zagents"
  rm -rf "$tmp"
  export PATH="$bin_dir:$PATH"
}

[ -n "${ZAGENTS_TOKEN:-}" ] || die "ZAGENTS_TOKEN is not set: create a workspace API token (Settings → API Tokens) and store it as a CI secret"
export ZAGENTS_TOKEN
export ZAGENTS_SERVER_URL="${ZAGENTS_SERVER_URL:-https://zagents.cnt.me}"
if [ -n "${ZAGENTS_WORKSPACE_ID:-}" ]; then
  export ZAGENTS_WORKSPACE_ID
fi

CLI="${ZAGENTS_CLI:-}"
if [ -z "$CLI" ]; then
  if ! command -v zagents >/dev/null 2>&1; then
    install_cli
  fi
  CLI=zagents
fi

log "$("$CLI" version 2>/dev/null | head -n 1 || echo zagents) → ${ZAGENTS_SERVER_URL}"
set +e
if [ "${1:-}" = drift ]; then
  shift
  "$CLI" spec drift "$@"
else
  "$CLI" spec test run "$@"
fi
code=$?
set -e
exit "$code"
