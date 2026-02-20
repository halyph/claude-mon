# Claude Code Monitoring Stack

A complete observability solution for monitoring Claude Code usage, costs, and performance using OpenTelemetry, Prometheus, Loki, and Grafana.

## Overview

This monitoring stack tracks:
- **Token usage** (input, output, cache reads/writes)
- **API costs** by model (Sonnet, Haiku, etc.)
- **Session activity** (active time, session count)
- **Cache efficiency** (hit rates)
- **Conversation logs** and tool execution history

## Architecture

```
Claude Code → OTLP (gRPC :4317) → OTel Collector → Prometheus (metrics)
                                                   → Loki (logs)
                                                   → Grafana (visualization)
```

## Prerequisites

- **Docker** and **Docker Compose** installed
- **Claude Code CLI** installed
- Terminal: macOS, Linux, or WSL on Windows

## Quick Start

### 1. Clone or Create the Repository

```bash
mkdir -p ~/claude-mon
cd ~/claude-mon
```

### 2. Start the Monitoring Stack

```bash
docker-compose up -d
```

This starts 4 services:
- **OTel Collector** (port 4317) - Telemetry ingestion
- **Prometheus** (port 9090) - Metrics storage
- **Loki** (port 3100) - Log aggregation
- **Grafana** (port 3000) - Visualization dashboard

Verify all services are running:

```bash
docker-compose ps
```

All services should show status `Up`.

### 3. Enable Claude Code Telemetry

Set the required environment variables to enable telemetry in Claude Code:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

**Make it permanent** by adding to your shell profile:

For **Zsh** (macOS default):
```bash
cat >> ~/.zshrc <<'EOF'
# Claude Code Telemetry
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
EOF

source ~/.zshrc
```

For **Bash**:
```bash
cat >> ~/.bashrc <<'EOF'
# Claude Code Telemetry
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
EOF

source ~/.bashrc
```

### 4. Verify Telemetry is Working

Run a simple Claude Code command to generate telemetry:

```bash
claude "echo hello"
```

Check if the OTel Collector is receiving data:

```bash
docker-compose logs --tail=20 otel-collector
```

You should see log entries showing received metrics and logs.

Check if metrics are in Prometheus:

```bash
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | grep claude_code
```

You should see metric names like `claude_code_cost_usage_USD_total`, `claude_code_token_usage_tokens_total`, etc.

### 5. Import the Grafana Dashboard

Open Grafana in your browser:

```bash
open http://localhost:3000
```

Or visit: http://localhost:3000

**Add Prometheus Data Source:**

1. Go to **Configuration** (⚙️) → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Configure:
   - **Name:** `Prometheus`
   - **URL:** `http://prometheus:9090`
5. Click **Save & Test** (should show green checkmark)

**Add Loki Data Source (optional, for logs):**

1. Click **Add data source** again
2. Select **Loki**
3. Configure:
   - **Name:** `Loki`
   - **URL:** `http://loki:3100`
4. Click **Save & Test**

**Import the Dashboard:**

1. Click **+** (Create) → **Import**
2. Click **Upload JSON file**
3. Select: `grafana-dashboard-claude-code.json` from this repository
4. Click **Load**
5. Select **Prometheus** as the data source
6. Click **Import**

The dashboard will open automatically and start showing your Claude Code usage!

### 6. View Your Metrics

The dashboard includes:

**Top Stats:**
- Total Cost (USD)
- Total Tokens Used
- Total Active Time
- Total Sessions

**Charts:**
- Cost by Model (time series)
- Token Usage by Type (input/output/cache)
- Cost Distribution (pie chart)
- Cache Hit Rate (gauge)
- Active Time by Type
- Session Details (table)

The dashboard auto-refreshes every 5 seconds.

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana** | http://localhost:3000 | Main dashboard UI |
| **Prometheus** | http://localhost:9090 | Metrics query UI |
| **Loki** | http://localhost:3100 | Log aggregation API |
| **OTel Collector** | http://localhost:4317 | OTLP gRPC endpoint |

## Common Commands

### View logs from all services
```bash
docker-compose logs -f
```

### View logs from a specific service
```bash
docker-compose logs -f otel-collector
docker-compose logs -f prometheus
docker-compose logs -f loki
docker-compose logs -f grafana
```

### Restart a specific service
```bash
docker-compose restart otel-collector
```

### Stop the entire stack
```bash
docker-compose down
```

### Stop and remove all data
```bash
docker-compose down -v
```

### Check service status
```bash
docker-compose ps
```

## Metrics Reference

### Available Metrics

| Metric | Description | Labels |
|--------|-------------|--------|
| `claude_code_cost_usage_USD_total` | Total cost in USD | model, session_id, terminal_type, user_id |
| `claude_code_token_usage_tokens_total` | Token count | model, session_id, type (input/output/cacheRead/cacheCreation), terminal_type, user_id |
| `claude_code_active_time_seconds_total` | Active session time | session_id, type (cli/user), terminal_type, user_id |
| `claude_code_session_count_total` | Number of sessions | session_id, terminal_type, user_id |

### Example Prometheus Queries

**Total cost across all sessions:**
```promql
sum(claude_code_cost_usage_USD_total)
```

**Cost by model:**
```promql
sum by (model) (claude_code_cost_usage_USD_total)
```

**Cache hit rate:**
```promql
sum(claude_code_token_usage_tokens_total{type="cacheRead"}) /
(sum(claude_code_token_usage_tokens_total{type="cacheRead"}) +
 sum(claude_code_token_usage_tokens_total{type="input"}))
```

**Tokens per hour:**
```promql
rate(claude_code_token_usage_tokens_total[1h]) * 3600
```

## Troubleshooting

### Telemetry not appearing in Grafana

1. **Check environment variables are set:**
   ```bash
   env | grep -E '(CLAUDE_CODE|OTEL)'
   ```
   Verify `CLAUDE_CODE_ENABLE_TELEMETRY=1`

2. **Verify OTel Collector is receiving data:**
   ```bash
   docker-compose logs --tail=50 otel-collector | grep -i received
   ```

3. **Check Prometheus is scraping metrics:**
   ```bash
   curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
   ```

4. **Restart the OTel Collector:**
   ```bash
   docker-compose restart otel-collector
   ```

### OTel Collector fails to start

1. **Check configuration syntax:**
   ```bash
   docker-compose logs otel-collector
   ```

2. **Validate YAML files:**
   ```bash
   cat otel-config.yaml
   ```

3. **Restart with clean state:**
   ```bash
   docker-compose down && docker-compose up -d
   ```

### Port conflicts

If ports 3000, 3100, 4317, 8889, or 9090 are already in use:

1. **Find what's using the port:**
   ```bash
   lsof -i :3000
   ```

2. **Either stop the conflicting service or edit `docker-compose.yml` to use different ports:**
   ```yaml
   ports:
     - "13000:3000"  # Use port 13000 instead of 3000
   ```

### Grafana dashboard shows "No Data"

1. **Verify data source configuration:**
   - Go to Grafana → Configuration → Data Sources
   - Test the Prometheus connection
   - Ensure URL is `http://prometheus:9090` (not `localhost`)

2. **Check if metrics exist:**
   ```bash
   curl -s 'http://localhost:8889/metrics' | grep claude_code
   ```

3. **Try running Claude Code to generate fresh data:**
   ```bash
   claude "test telemetry"
   ```

## Configuration Files

### otel-config.yaml
Configures the OpenTelemetry Collector:
- **Receivers:** OTLP gRPC on port 4317
- **Exporters:** Prometheus (metrics), Loki (logs), Debug (console)
- **Pipelines:** Routes metrics and logs to appropriate exporters

### prometheus-config.yaml
Configures Prometheus scraping:
- **Scrape interval:** 5 seconds
- **Target:** OTel Collector metrics endpoint (port 8889)

### docker-compose.yml
Defines all services and their networking:
- Service configurations
- Port mappings
- Volume mounts for configs
- Grafana anonymous access (for easy setup)

## Security Notes

⚠️ **This setup is for local development/monitoring only**

- Grafana is configured with anonymous admin access (no login required)
- No authentication on any services
- All ports are exposed to localhost

For production use:
- Enable authentication on all services
- Use proper secrets management
- Restrict network access
- Enable TLS/SSL
- Use a reverse proxy

## Advanced Usage

### Custom Grafana Dashboards

Create your own dashboards using the available metrics. Some ideas:

- **Daily cost trends**
- **Token usage by project** (if you tag sessions)
- **Model comparison** (Sonnet vs Haiku efficiency)
- **Cache efficiency over time**
- **Session duration analysis**

### Exporting Data

**Export metrics from Prometheus:**
```bash
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=claude_code_cost_usage_USD_total' | jq
```

**Export dashboard:**
In Grafana, go to Dashboard Settings → JSON Model → Copy to clipboard

### Alerting

Configure Grafana alerts for:
- Cost thresholds (e.g., alert if daily cost > $10)
- Unusual token usage spikes
- Cache hit rate drops below threshold

## Contributing

Feel free to enhance this monitoring stack:

- Add more dashboard panels
- Improve visualizations
- Add alerting rules
- Create additional exporters
- Submit PRs with improvements

## Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Claude Code Documentation](https://claude.ai/code)

## License

This monitoring stack configuration is provided as-is for monitoring Claude Code usage.
