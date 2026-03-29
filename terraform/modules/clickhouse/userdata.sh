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
