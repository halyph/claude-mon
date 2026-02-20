#!/bin/bash
set -e

echo "🚀 Claude Code Monitoring Stack Setup"
echo "======================================"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found. Please install Docker and Docker Compose first."
    exit 1
fi

# Start services
echo "📦 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if Grafana is ready
until curl -s http://localhost:3000/api/health > /dev/null 2>&1; do
    echo "   Waiting for Grafana..."
    sleep 2
done

echo "✅ Services are up!"
echo ""

# Configure Grafana data sources
echo "🔧 Configuring Grafana data sources..."

# Add Prometheus data source with fixed UID
curl -s -X POST \
  http://localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "uid": "prometheus-claude-code",
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }' > /dev/null && echo "   ✓ Prometheus data source added"

# Add Loki data source with fixed UID
curl -s -X POST \
  http://localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "uid": "loki-claude-code",
    "name": "Loki",
    "type": "loki",
    "url": "http://loki:3100",
    "access": "proxy"
  }' > /dev/null && echo "   ✓ Loki data source added"

# Import dashboards
echo "📊 Importing Claude Code dashboards..."

# Function to import a dashboard
import_dashboard() {
    local DASHBOARD_FILE=$1
    local DASHBOARD_NAME=$2

    if [ -f "$DASHBOARD_FILE" ]; then
        # Create temporary dashboard file with correct datasource UIDs
        TEMP_DASHBOARD=$(mktemp)
        sed 's/"uid": "PROMETHEUS_UID"/"uid": "prometheus-claude-code"/g' "$DASHBOARD_FILE" | \
        sed 's/"uid": "LOKI_UID"/"uid": "loki-claude-code"/g' > "$TEMP_DASHBOARD"

        RESPONSE=$(curl -s -X POST \
          http://localhost:3000/api/dashboards/db \
          -H 'Content-Type: application/json' \
          -d @"$TEMP_DASHBOARD")

        rm "$TEMP_DASHBOARD"

        if echo "$RESPONSE" | grep -q '"status":"success"'; then
            echo "   ✓ $DASHBOARD_NAME imported successfully"
        else
            echo "   ⚠️  $DASHBOARD_NAME import failed: $RESPONSE"
        fi
    else
        echo "   ✗ Dashboard file not found: $DASHBOARD_FILE"
        exit 1
    fi
}

# Import metrics dashboard
import_dashboard "config/grafana/dashboards/claude-code-monitoring.json" "Metrics dashboard"

# Import logs dashboard
import_dashboard "config/grafana/dashboards/claude-code-logs.json" "Logs dashboard"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📍 Service URLs:"
echo "   Grafana:    http://localhost:3000"
echo "   Prometheus: http://localhost:9090"
echo "   Loki:       http://localhost:3100"
echo ""
echo "📊 Grafana Dashboards:"
echo "   Metrics:    http://localhost:3000/d/claude-code-monitoring"
echo "   Logs:       http://localhost:3000/d/claude-code-logs"
echo ""
echo "📝 Next steps:"
echo "   1. Configure Claude Code telemetry in ~/.claude/settings.json"
echo "   2. Run: claude 'test telemetry'"
echo "   3. Open dashboards above to view metrics and logs"
echo ""
