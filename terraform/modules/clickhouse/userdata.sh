#!/bin/bash
set -euo pipefail

# Install ClickHouse 24.8
yum install -y yum-utils
yum-config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo
yum install -y clickhouse-server-24.8* clickhouse-client-24.8*

# Configure ClickHouse to listen on all interfaces (VPC-internal access)
mkdir -p /etc/clickhouse-server/config.d
cat > /etc/clickhouse-server/config.d/listen.xml << 'EOF'
<clickhouse>
    <listen_host>0.0.0.0</listen_host>
</clickhouse>
EOF

# Start ClickHouse
systemctl enable clickhouse-server
systemctl start clickhouse-server

# Create databases
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS bronze"
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS silver"
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS gold"
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS feature_store"

# === Grafana OSS Installation ===
# Self-hosted Grafana on ClickHouse EC2 (AMG not available in eu-north-1)
# Port 3000, accessible via bastion SSH tunnel

cat <<'GRAFANA_REPO' > /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
GRAFANA_REPO

yum install -y grafana

# Install ClickHouse datasource plugin
grafana-cli plugins install grafana-clickhouse-datasource

# Fix permissions
chown -R grafana:grafana /var/lib/grafana /var/log/grafana /etc/grafana

# Set admin password
sed -i 's/;admin_password = admin/admin_password = paystream/' /etc/grafana/grafana.ini

# Enable and start Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
