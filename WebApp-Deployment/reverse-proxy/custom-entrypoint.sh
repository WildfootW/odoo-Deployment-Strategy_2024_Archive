#! /bin/sh
#
# custom-entrypoint.sh
# © 2024 Andrew Shen <wildfootw@hoschoc.com>
#
# Distributed under the same license as Webapp-Deployment
#

set -e

# Define the list of domains (can also be set via environment variable)
DOMAINS=${DOMAINS:-"portal.example.com"}

# Loop through each domain to process SSL configuration
for DOMAIN in $DOMAINS; do
  # Define the SSL configuration file for the current domain
  SSL_CONF_FILE="/etc/nginx/conf.d/ssl/external_$DOMAIN.include"

  # Check if the SSL configuration file exists
  if [ ! -f "$SSL_CONF_FILE" ]; then
    echo "[custom-entrypoint.sh ERROR] SSL configuration file $SSL_CONF_FILE not found. Exiting."
    exit 1
  fi

  # Define paths for Let's Encrypt and self-signed certificates
  LETSENCRYPT_CERT="/etc/nginx/certs/letsencrypt/live/$DOMAIN/fullchain.pem"
  LETSENCRYPT_KEY="/etc/nginx/certs/letsencrypt/live/$DOMAIN/privkey.pem"

  SELF_SIGNED_CERT="/etc/nginx/certs/self-signed/$DOMAIN.crt"
  SELF_SIGNED_KEY="/etc/nginx/certs/self-signed/$DOMAIN.key"

  # Determine which certificates to use
  if [ -f "$LETSENCRYPT_CERT" ] && [ -f "$LETSENCRYPT_KEY" ]; then
    # Use Let's Encrypt certificates
    SSL_CERTIFICATE="$LETSENCRYPT_CERT"
    SSL_CERTIFICATE_KEY="$LETSENCRYPT_KEY"
    echo "[custom-entrypoint.sh INFO] Using Let's Encrypt certificate for $DOMAIN"
  elif [ -f "$SELF_SIGNED_CERT" ] && [ -f "$SELF_SIGNED_KEY" ]; then
    # Use self-signed certificates
    SSL_CERTIFICATE="$SELF_SIGNED_CERT"
    SSL_CERTIFICATE_KEY="$SELF_SIGNED_KEY"
    echo "[custom-entrypoint.sh INFO] Using self-signed certificate for $DOMAIN"
  else
    echo "[custom-entrypoint.sh ERROR] No certificates found for $DOMAIN. Exiting."
    exit 1
  fi

  # Export variables for envsubst
  export SSL_CERTIFICATE
  export SSL_CERTIFICATE_KEY
  # Check values before envsubst
  echo "[custom-entrypoint.sh DEBUG] SSL_CERTIFICATE=$SSL_CERTIFICATE"
  echo "[custom-entrypoint.sh DEBUG] SSL_CERTIFICATE_KEY=$SSL_CERTIFICATE_KEY"

  # Use envsubst to replace variables in the SSL configuration file
  envsubst '${SSL_CERTIFICATE} ${SSL_CERTIFICATE_KEY}' < "$SSL_CONF_FILE" > "$SSL_CONF_FILE.tmp"
  mv "$SSL_CONF_FILE.tmp" "$SSL_CONF_FILE"

done

# Execute the original entrypoint script
exec /docker-entrypoint.sh "$@"
