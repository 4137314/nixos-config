#!/usr/bin/env bash
#
# scripts/first-switch.sh — bootstrap the box for the very first activation.
#
# Runs (idempotently) all the manual steps that would otherwise fail on a
# clean box: creates directories, generates random passwords, writes them
# to /etc/… and /var/lib/… with the correct owner/mode, and dumps a
# single journal file at /root/.hackerbox-passwords so you have every
# generated secret in one place.
#
# Usage:
#   sudo bash /etc/nixos/scripts/first-switch.sh
#
# After it prints "READY", run:
#   sudo nixos-rebuild switch --flake /etc/nixos/#nixos-hacker-box
#
# The rebuild will download ~50 GB (Ollama models + container images +
# ROCm stack). Plan for 20-60 min depending on your connection.

set -euo pipefail
umask 077

if [[ $EUID -ne 0 ]]; then
  echo "must run as root: sudo bash $0" >&2
  exit 1
fi

echo "==> first-switch bootstrap starting"

# ------------------------------------------------------------------
# 0. Ensure tools we need are on PATH (openssl comes from nix profile).
# ------------------------------------------------------------------
OPENSSL="$(command -v openssl || echo /run/current-system/sw/bin/openssl)"
if [[ ! -x $OPENSSL ]]; then
  echo "openssl not found — install with: nix-env -iA nixpkgs.openssl" >&2
  exit 1
fi

gen() { $OPENSSL rand -base64 32 | tr -d '\n'; }
gen_long() { $OPENSSL rand -base64 48 | tr -d '\n'; }

JOURNAL=/root/.hackerbox-passwords
: >"$JOURNAL"
chmod 600 "$JOURNAL"

log() {
  printf '%s\n' "$*" | tee -a "$JOURNAL"
}

log "# hackerbox first-switch — generated $(date -Iseconds)"
log ""

# ------------------------------------------------------------------
# 1. System-level admin password files.
# ------------------------------------------------------------------
if [[ ! -s /etc/nextcloud-admin-pass ]]; then
  P=$(gen)
  printf '%s' "$P" >/etc/nextcloud-admin-pass
  chmod 600 /etc/nextcloud-admin-pass
  log "NEXTCLOUD  user=admin  pass=$P"
fi

if [[ ! -s /etc/grafana-admin-pass ]]; then
  P=$(gen)
  printf '%s' "$P" >/etc/grafana-admin-pass
  chmod 640 /etc/grafana-admin-pass
  # grafana group might not exist yet; chown happens at systemd tmpfiles time.
  log "GRAFANA    user=admin  pass=$P"
fi

# ------------------------------------------------------------------
# 2. Ntfy placeholders. Real tokens produced after ntfy user creation.
# ------------------------------------------------------------------
mkdir -p /etc/ntfy
if [[ ! -s /etc/ntfy/grafana-token ]]; then
  printf 'placeholder-token-set-after-first-boot' >/etc/ntfy/grafana-token
  chmod 640 /etc/ntfy/grafana-token
  log "NTFY_GRAFANA_TOKEN  = placeholder (rotate via ntfy CLI post-boot)"
fi

# ------------------------------------------------------------------
# 3. Restic — repository password + env. Placeholder until you sign up
#    for a backup destination (B2 / Storj / SSH remote).
# ------------------------------------------------------------------
mkdir -p /etc/restic
if [[ ! -s /etc/restic/repo-password ]]; then
  P=$(gen_long)
  printf '%s' "$P" >/etc/restic/repo-password
  chmod 400 /etc/restic/repo-password
  log "RESTIC_REPO_PASSWORD  = $P"
fi
if [[ ! -s /etc/restic/env ]]; then
  cat >/etc/restic/env <<'EOF'
B2_ACCOUNT_ID=placeholder-fill-me-in
B2_ACCOUNT_KEY=placeholder-fill-me-in
EOF
  chmod 400 /etc/restic/env
  log "RESTIC_ENV            = /etc/restic/env  (edit with real B2 creds)"
fi

# ------------------------------------------------------------------
# 4. Miniflux admin credentials.
# ------------------------------------------------------------------
mkdir -p /var/lib/miniflux
if [[ ! -s /var/lib/miniflux/admin-pass ]]; then
  P=$(gen)
  cat >/var/lib/miniflux/admin-pass <<EOF
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$P
EOF
  chmod 640 /var/lib/miniflux/admin-pass
  # miniflux user is created by the systemd unit — chown on start.
  log "MINIFLUX  user=admin  pass=$P"
fi

# ------------------------------------------------------------------
# 5. Vaultwarden admin token.
# ------------------------------------------------------------------
mkdir -p /var/lib/vaultwarden
if [[ ! -s /var/lib/vaultwarden/admin.env ]]; then
  P=$(gen_long)
  echo "ADMIN_TOKEN=$P" >/var/lib/vaultwarden/admin.env
  chmod 600 /var/lib/vaultwarden/admin.env
  log "VAULTWARDEN_ADMIN_TOKEN  = $P"
fi

# ------------------------------------------------------------------
# 6. Hub container credentials.
# ------------------------------------------------------------------
mkdir -p /var/lib/hub

# Firefly III — DB password + APP_KEY.
mkdir -p /var/lib/hub/firefly
if [[ ! -s /var/lib/hub/firefly/db.env ]]; then
  DB=$(gen)
  APP=$($OPENSSL rand -base64 32)
  echo "POSTGRES_PASSWORD=$DB" >/var/lib/hub/firefly/db.env
  cat >/var/lib/hub/firefly/app.env <<EOF
APP_KEY=base64:$APP
DB_PASSWORD=$DB
EOF
  chmod 600 /var/lib/hub/firefly/{db,app}.env
  log "FIREFLY   db_pass=$DB"
  log "FIREFLY   app_key=base64:$APP"
fi

# Ghostfolio — DB + Redis + JWT.
mkdir -p /var/lib/hub/ghostfolio
if [[ ! -s /var/lib/hub/ghostfolio/db.env ]]; then
  GD=$(gen)
  GR=$(gen)
  ATS=$(gen)
  JWT=$(gen)
  echo "POSTGRES_PASSWORD=$GD" >/var/lib/hub/ghostfolio/db.env
  echo "REDIS_PASSWORD=$GR" >/var/lib/hub/ghostfolio/redis.env
  cat >/var/lib/hub/ghostfolio/app.env <<EOF
ACCESS_TOKEN_SALT=$ATS
JWT_SECRET_KEY=$JWT
REDIS_PASSWORD=$GR
EOF
  chmod 600 /var/lib/hub/ghostfolio/{db,redis,app}.env
  log "GHOSTFOLIO db_pass=$GD  jwt_secret=$JWT"
fi

# Karakeep — NEXTAUTH_SECRET + MEILI master key.
mkdir -p /var/lib/hub/karakeep
if [[ ! -s /var/lib/hub/karakeep/env ]]; then
  NA=$(gen)
  MK=$(gen)
  cat >/var/lib/hub/karakeep/env <<EOF
NEXTAUTH_SECRET=$NA
MEILI_MASTER_KEY=$MK
EOF
  chmod 600 /var/lib/hub/karakeep/env
  log "KARAKEEP  nextauth=$NA  meili=$MK"
fi

# Flowise — admin password.
if [[ ! -s /var/lib/ai/flowise.env ]]; then
  mkdir -p /var/lib/ai
  P=$(gen)
  echo "FLOWISE_PASSWORD=$P" >/var/lib/ai/flowise.env
  chmod 600 /var/lib/ai/flowise.env
  log "FLOWISE   user=admin  pass=$P"
fi

# Archivebox — admin password.
mkdir -p /var/lib/hub/archivebox
if [[ ! -s /var/lib/hub/archivebox/env ]]; then
  P=$(gen)
  echo "ADMIN_PASSWORD=$P" >/var/lib/hub/archivebox/env
  chmod 600 /var/lib/hub/archivebox/env
  log "ARCHIVEBOX user=admin  pass=$P"
fi

# SilverBullet — basic-auth user:pass.
mkdir -p /var/lib/hub/silverbullet
if [[ ! -s /var/lib/hub/silverbullet/env ]]; then
  P=$(gen)
  echo "SB_USER=admin:$P" >/var/lib/hub/silverbullet/env
  chmod 600 /var/lib/hub/silverbullet/env
  log "SILVERBULLET user=admin  pass=$P"
fi

# ------------------------------------------------------------------
# 7. SearXNG secret (container reads it from /etc/searxng/secret).
# ------------------------------------------------------------------
mkdir -p /var/lib/ai/searxng
if [[ ! -s /var/lib/ai/searxng/secret ]]; then
  $OPENSSL rand -hex 32 >/var/lib/ai/searxng/secret
  chmod 600 /var/lib/ai/searxng/secret
  log "SEARXNG_SECRET  = generated in /var/lib/ai/searxng/secret"
fi

# ------------------------------------------------------------------
# 8. Ownership fixes (owners might not exist yet — try, ignore fail).
# ------------------------------------------------------------------
chown -R nextcloud:nextcloud /etc/nextcloud-admin-pass 2>/dev/null || true
chown grafana:grafana /etc/grafana-admin-pass 2>/dev/null || true
chown grafana:grafana /etc/ntfy/grafana-token 2>/dev/null || true
chown miniflux:miniflux /var/lib/miniflux/admin-pass 2>/dev/null || true
chown vaultwarden:vaultwarden /var/lib/vaultwarden/admin.env 2>/dev/null || true

echo ""
echo "==> READY"
echo ""
echo "All generated credentials are in $JOURNAL (chmod 600, root-only)."
echo ""
echo "Next steps:"
echo ""
echo "  1. Preview the rebuild without applying:"
echo "       sudo nixos-rebuild dry-activate --flake /etc/nixos/#nixos-hacker-box"
echo ""
echo "  2. Apply (will download ~50 GB Ollama models + containers):"
echo "       sudo nixos-rebuild switch --flake /etc/nixos/#nixos-hacker-box"
echo ""
echo "  3. After first boot, verify each service:"
echo "       systemctl --failed"
echo "       systemctl status ollama open-webui vaultwarden nextcloud"
echo "       curl -sf http://127.0.0.1:11434/api/tags | jq"
echo ""
echo "  4. Check ROCm sees the GPU (Polaris — best-effort):"
echo "       rocminfo | grep -A1 'Marketing Name'"
echo "       ollama run llama3.2:3b 'say hello in italian'"
