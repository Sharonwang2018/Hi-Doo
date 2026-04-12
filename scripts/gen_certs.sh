#!/bin/bash
# Generate HTTPS certs for 10.0.0.138
# Run once: ./scripts/gen_certs.sh
# For trusted certs (no browser warning): brew install mkcert && mkcert -install

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/../server/certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

if command -v mkcert &>/dev/null; then
  echo "Using mkcert (trusted local certs)..."
  mkcert -key-file key.pem -cert-file cert.pem 10.0.0.138 localhost 127.0.0.1
  echo "✅ Certs: $CERT_DIR/"
else
  echo "Using openssl (self-signed, browser will show warning)..."
  openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
    -subj "/CN=10.0.0.138" -addext "subjectAltName=IP:10.0.0.138,DNS:localhost,IP:127.0.0.1"
  echo "✅ Certs: $CERT_DIR/"
  echo "   Install mkcert (brew install mkcert) for trusted certs without browser warning"
fi
