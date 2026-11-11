#!/bin/sh
# Validates the store: app folders, manifests and compose files. Used by CI; runs locally
# with Docker and Python 3 + PyYAML:  sh scripts/validate.sh
set -eu
cd "$(dirname "$0")/.."
status=0
fail() { echo "error: $*" >&2; status=1; }

store_id=$(python3 -c 'import yaml; print(yaml.safe_load(open("umbrel-app-store.yml"))["id"])')
[ "$store_id" = olymp ] || fail "umbrel-app-store.yml: id must be olymp, is $store_id"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# umbrelOS adds the app_proxy image itself; give it a stand-in so Compose can parse the file.
printf 'services:\n  app_proxy:\n    image: busybox\n' > "$tmp/app-proxy.yml"

apps=0
for manifest in */umbrel-app.yml; do
  [ -e "$manifest" ] || continue
  apps=$((apps + 1))
  dir=${manifest%/umbrel-app.yml}
  app_id=$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["id"])' "$manifest")
  [ "$app_id" = "$dir" ] || fail "$manifest: id $app_id does not match folder $dir"
  case "$dir" in olymp-*) ;; *) fail "$dir: app folders must start with olymp-" ;; esac
  python3 - "$manifest" <<'PY' || status=1
import sys, yaml
m = yaml.safe_load(open(sys.argv[1]))
required = ["manifestVersion", "id", "name", "tagline", "description", "category",
            "version", "port", "storage", "gallery", "dependencies", "path"]
missing = [k for k in required if k not in m]
if missing:
    sys.exit(f"error: {sys.argv[1]}: missing {', '.join(missing)}")
if not 1024 <= int(m["port"]) <= 65535 or 40000 <= int(m["port"]) <= 49999:
    sys.exit(f"error: {sys.argv[1]}: port {m['port']} not allowed (1024-65535, not 40000-49999)")
PY
  [ -f "$dir/docker-compose.yml" ] || { fail "$dir: docker-compose.yml missing"; continue; }
  if ! APP_DATA_DIR="$tmp/$dir" docker compose -p "$dir" \
      -f "$dir/docker-compose.yml" -f "$tmp/app-proxy.yml" config --quiet; then
    fail "$dir/docker-compose.yml: docker compose config failed"
  fi
  grep -n 'build:' "$dir/docker-compose.yml" && fail "$dir: no build: in store compose files"
  grep -nE '^\s*image:' "$dir/docker-compose.yml" | grep -v '@sha256:[0-9a-f]\{64\}' \
    && fail "$dir: pin every image as tag@sha256:<digest>"
done
[ "$apps" -gt 0 ] || fail "no apps found"

# Public repository: nothing secret or personal.
if git grep -nIE --untracked \
  -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
  -e '\.ts\.net' \
  -e '[0-9]{6,}:[A-Za-z0-9_-]{30,}' \
  -e '(gh[pousr]_|github_pat_)[A-Za-z0-9_]{20,}' \
  -e 'sk-ant-[A-Za-z0-9_-]+' \
  -e '(CHAT_ID|chat_id)[=: ]+["'"'"']?-?[0-9]{5,}' \
  -e '(TOKEN|SECRET|PASSWORD)[=: ]+["'"'"']?[A-Za-z0-9_./+-]{16,}' \
  -- . ':!scripts/validate.sh'; then
  fail "possible secret or personal data (lines above)"
fi

[ "$status" -eq 0 ] && echo "store ok ($apps apps)"
exit "$status"
