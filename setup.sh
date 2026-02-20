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

# Add Prometheus data source
curl -s -X POST \
  http://localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }' > /dev/null && echo "   ✓ Prometheus data source added"

# Add Loki data source
curl -s -X POST \
  http://localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://loki:3100",
    "access": "proxy"
  }' > /dev/null && echo "   ✓ Loki data source added"

# Import dashboard
echo "📊 Importing Claude Code dashboard..."
DASHBOARD_FILE="config/grafana/dashboards/claude-code-monitoring.json"

if [ -f "$DASHBOARD_FILE" ]; then
    RESPONSE=$(curl -s -X POST \
      http://localhost:3000/api/dashboards/db \
      -H 'Content-Type: application/json' \
      -d @"$DASHBOARD_FILE")

    if echo "$RESPONSE" | grep -q '"status":"success"'; then
        echo "   ✓ Dashboard imported successfully"
    else
        echo "   ⚠️  Dashboard import failed: $RESPONSE"
    fi
else
    echo "   ✗ Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi

echo ""
echo "✅ Setup complete!"
echo "" 
echo "📍 Service URLs:"
echo "   Grafana:    http://localhost:3000"
echo "   Prometheus: http://localhost:9090"
echo "   Loki:       http://localhost:3100"
echo ""
echo "📝 Next steps:"
echo "   1. Configure Claude Code telemetry in ~/.claude/settings.json"
echo "   2. Run: claude 'test telemetry'"
echo "   3. Open Grafana dashboard: http://localhost:3000/d/claude-code-monitoring"
echo ""
