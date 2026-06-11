#!/usr/bin/env bash
# Deploys the Komorebi Arena backend (PocketBase) to the theinvalid VPS.
#
#   ./server/arena/deploy.sh            # full deploy: binary, systemd, caddy, DNS, collection
#
# Prereqs (already true on theinvalid-vps): Caddy + UFW(80/443) installed,
# SSH key at ~/.ssh/hetzner_ed25519, Cloudflare token at
# ~/.config/mushishi-infra/cloudflare.token (Zone DNS edit).
#
# Idempotent: safe to re-run.
set -euo pipefail

VPS=mushi@178.105.200.212
SSH="ssh -i $HOME/.ssh/hetzner_ed25519 -o BatchMode=yes $VPS"
PB_VERSION=0.39.3
DOMAIN=arena.theinvalid.me
CRED_FILE=$HOME/.config/mushishi-infra/pocketbase-arena.credentials

echo "==> 1/5 PocketBase binary + systemd"
$SSH 'bash -s' <<EOF
set -e
sudo mkdir -p /opt/pocketbase
cd /tmp
curl -sL -o pb.zip https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip
sudo unzip -o -q pb.zip pocketbase -d /opt/pocketbase && rm pb.zip
sudo useradd -r -s /usr/sbin/nologin pocketbase 2>/dev/null || true
sudo chown -R pocketbase:pocketbase /opt/pocketbase
sudo tee /etc/systemd/system/pocketbase.service >/dev/null <<'UNIT'
[Unit]
Description=PocketBase (Komorebi Arena)
After=network.target

[Service]
Type=simple
User=pocketbase
Group=pocketbase
WorkingDirectory=/opt/pocketbase
ExecStart=/opt/pocketbase/pocketbase serve --http=127.0.0.1:8090
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/pocketbase

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now pocketbase
sleep 2
curl -fsS http://127.0.0.1:8090/api/health >/dev/null && echo "   pocketbase healthy"
EOF

echo "==> 2/5 Superuser (created once; credentials -> $CRED_FILE)"
if [ ! -f "$CRED_FILE" ]; then
  PB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
  $SSH "sudo -u pocketbase /opt/pocketbase/pocketbase superuser upsert arena@theinvalid.me '$PB_PASS' --dir /opt/pocketbase/pb_data"
  mkdir -p "$(dirname "$CRED_FILE")"
  printf 'email=arena@theinvalid.me\npassword=%s\n' "$PB_PASS" > "$CRED_FILE"
  chmod 600 "$CRED_FILE"
  echo "   superuser created"
else
  echo "   credentials file exists — skipping"
fi

echo "==> 3/5 Cloudflare DNS ($DOMAIN -> 178.105.200.212, DNS-only for ACME)"
CF_TOKEN=$(cat "$HOME/.config/mushishi-infra/cloudflare.token")
ZONE=$(curl -fsS -H "Authorization: Bearer $CF_TOKEN" \
  'https://api.cloudflare.com/client/v4/zones?name=theinvalid.me' |
  python3 -c 'import json,sys;print(json.load(sys.stdin)["result"][0]["id"])')
EXISTS=$(curl -fsS -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records?name=$DOMAIN" |
  python3 -c 'import json,sys;print(len(json.load(sys.stdin)["result"]))')
if [ "$EXISTS" = "0" ]; then
  curl -fsS -X POST -H "Authorization: Bearer $CF_TOKEN" \
    -H 'Content-Type: application/json' \
    "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
    -d "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"178.105.200.212\",\"proxied\":false}" >/dev/null
  echo "   A record created"
else
  echo "   record exists — skipping"
fi

echo "==> 4/5 Caddy site"
$SSH 'bash -s' <<EOF
set -e
if ! grep -q '$DOMAIN' /etc/caddy/Caddyfile; then
  sudo tee -a /etc/caddy/Caddyfile >/dev/null <<'SITE'

arena.theinvalid.me {
    reverse_proxy 127.0.0.1:8090
}
SITE
  sudo systemctl reload caddy
  echo "   caddy site added"
else
  echo "   caddy site exists — skipping"
fi
EOF

echo "==> 5/5 scores collection + API rules"
python3 "$(dirname "$0")/setup_collection.py" "https://$DOMAIN" "$CRED_FILE"

echo "==> done. Try: curl https://$DOMAIN/api/health"
