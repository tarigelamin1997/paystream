#!/bin/bash
set -e

PEM_FILE="$1"
TRUSTSTORE="$2"
STOREPASS="${3:-changeit}"

# Split PEM bundle into individual certs and import each into the truststore
i=0
cert=""
while IFS= read -r line; do
  cert="${cert}${line}
"
  if [ "$line" = "-----END CERTIFICATE-----" ]; then
    i=$((i + 1))
    echo "$cert" > "/tmp/import-cert-${i}.pem"
    keytool -importcert -trustcacerts -noprompt \
      -alias "rds-ca-${i}" \
      -file "/tmp/import-cert-${i}.pem" \
      -keystore "$TRUSTSTORE" \
      -storepass "$STOREPASS" 2>/dev/null || true
    rm -f "/tmp/import-cert-${i}.pem"
    cert=""
  fi
done < "$PEM_FILE"

echo "Imported ${i} certificates into ${TRUSTSTORE}"
