#!/usr/bin/env bash
# mz: spec-kit — check that the Spec Kit job is a REQUIRED status check on a
# branch (classic branch protection or repository rulesets), so a red spec
# gate actually blocks the merge. Read only (gh api GET).
#
#   bash scripts/spec-kit-verify-protection.sh --repo acme/catalog --branch main --check spec-tests
#
# Exit codes: 0 required; 1 not required (or no protection); 2 usage / gh error.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: spec-kit-verify-protection.sh [--repo OWNER/REPO] [--branch BRANCH] [--check NAME]...

Prints whether each check NAME (default: spec-tests) is a required status
check on BRANCH (default: the repository's default branch), via classic
branch protection or rulesets. Needs gh (authenticated) and jq.

  --repo     default: the current gh repository
  --branch   default: the repository's default branch
  --check    status check (job) name; repeat for several

Exit codes: 0 all required; 1 some not required; 2 usage or gh error.
EOF
}

die() { printf 'spec-kit-verify-protection: %s\n' "$*" >&2; exit 2; }

repo="" branch="" checks=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --branch) branch="${2:-}"; shift 2 ;;
    --check) checks+=("${2:-}"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done
[ ${#checks[@]} -gt 0 ] || checks=(spec-tests)
command -v gh >/dev/null 2>&1 || die "gh is not installed"
command -v jq >/dev/null 2>&1 || die "jq is not installed"

if [ -z "$repo" ]; then
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || die "cannot detect the repository; pass --repo OWNER/REPO"
fi
if [ -z "$branch" ]; then
  branch=$(gh api "repos/$repo" -q .default_branch 2>/dev/null) || die "cannot read repos/$repo (token scope or name)"
fi

# Required check names from classic protection (404 = none) and rulesets.
classic=$(gh api "repos/$repo/branches/$branch/protection/required_status_checks" 2>/dev/null |
  jq -r '((.contexts // []) + [(.checks // [])[].context]) | .[]' 2>/dev/null || true)
rules=$(gh api "repos/$repo/rules/branches/$branch" 2>/dev/null |
  jq -r '.[] | select(.type == "required_status_checks") | (.parameters.required_status_checks // [])[].context' 2>/dev/null || true)
required=$(printf '%s\n%s\n' "$classic" "$rules" | sed '/^$/d' | sort -u)

missing=0
for c in "${checks[@]}"; do
  if printf '%s\n' "$required" | grep -Fxq -- "$c"; then
    echo "ok: '$c' is a required status check on $repo@$branch"
  else
    echo "NOT REQUIRED: '$c' on $repo@$branch — add it in Settings → Branches (or Rules) → Require status checks to pass"
    missing=1
  fi
done
if [ -n "$required" ]; then
  echo "required checks: $(printf '%s\n' "$required" | paste -sd, - | sed 's/,/, /g')"
else
  echo "no required status checks on $repo@$branch"
fi
exit "$missing"
