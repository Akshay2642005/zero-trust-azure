#!/usr/bin/env bash
#
# Publish a new version of one of the shared modules to the HCP Terraform
# private registry (VCS-less publishing: create a version, then upload a
# tarball with the module at the archive root).
#
# Usage:
#   scripts/publish-module.sh <module> <version>
#
#   <module>   network | storage | policy
#   <version>  semantic version, e.g. 1.1.0
#
# Auth (one of):
#   export TF_TOKEN_app_terraform_io=...   # HCP token with "Manage modules"
#   # or a token stored in ~/.terraform.d/credentials.tfrc.json
#
set -euo pipefail

ORG="${TF_CLOUD_ORG:-akshay2642005}"
PROVIDER=azurerm
API=https://app.terraform.io/api/v2

MODULE="${1:-}"
VERSION="${2:-}"
if [[ -z "$MODULE" || -z "$VERSION" ]]; then
  echo "usage: $0 <network|storage|policy> <version>" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="$REPO_ROOT/modules/$MODULE"
[[ -d "$MODULE_DIR" ]] || { echo "no such module: modules/$MODULE" >&2; exit 2; }

TOKEN="${TF_TOKEN_app_terraform_io:-}"
if [[ -z "$TOKEN" ]]; then
  creds="$HOME/.terraform.d/credentials.tfrc.json"
  [[ -f "$creds" ]] || { echo "no TF_TOKEN_app_terraform_io and no $creds" >&2; exit 2; }
  TOKEN=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['credentials']['app.terraform.io']['token'])" "$creds")
fi

auth=(-H "Authorization: Bearer $TOKEN")
json=(-H "Content-Type: application/vnd.api+json")

echo "Publishing $ORG/$MODULE/$PROVIDER@$VERSION ..."

# 1. Ensure the module record exists (ignore 422 = already exists).
payload="{\"data\":{\"type\":\"registry-modules\",\"attributes\":{\"name\":\"$MODULE\",\"provider\":\"$PROVIDER\",\"registry-name\":\"private\"}}}"
code=$(curl -s -o /dev/null -w '%{http_code}' "${auth[@]}" "${json[@]}" -X POST --data "$payload" "$API/organizations/$ORG/registry-modules")
echo "  create module -> HTTP $code"

# 2. Create the version and capture the upload URL.
payload="{\"data\":{\"type\":\"registry-module-versions\",\"attributes\":{\"version\":\"$VERSION\"}}}"
body=$(curl -s -w $'\n%{http_code}' "${auth[@]}" "${json[@]}" -X POST --data "$payload" \
  "$API/organizations/$ORG/registry-modules/private/$ORG/$MODULE/$PROVIDER/versions")
code=$(tail -n1 <<<"$body")
echo "  create version -> HTTP $code"
if [[ "$code" != "201" ]]; then echo "$body" | sed '$d' >&2; exit 1; fi

upload=$(sed '$d' <<<"$body" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['links']['upload'])")

# 3. Package the module (contents at the archive root) and upload it.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
( cd "$MODULE_DIR" && tar czf "$tmp/module.tar.gz" * )
ucode=$(curl -s -o /dev/null -w '%{http_code}' "${auth[@]}" -H 'Content-Type: application/octet-stream' \
  -X PUT --data-binary "@$tmp/module.tar.gz" "$upload")
echo "  upload ($(du -h "$tmp/module.tar.gz" | cut -f1)) -> HTTP $ucode"

echo "Done. Pin it in envs/dev/main.tf:  version = \"$VERSION\""
