# Claude Code Monitoring Stack

Monitor Claude Code usage, costs, and performance using OpenTelemetry, Prometheus, Loki, and Grafana.

> **Tested with**: Claude Code CLI v2.1.38
> **Environment**: macOS with Colima (Docker Desktop alternative)

## ⚠️ Environment Note

This setup was developed and tested using [Colima](https://github.com/abiosoft/colima) on macOS. While it should work with Docker Desktop and other Docker environments, there may be networking or volume mounting differences. If you encounter issues on other platforms, please check your Docker configuration.

## Architecture

```mermaid
graph LR
    A[Claude Code] -->|OTLP gRPC :4317| B[OTel Collector]
    B -->|Metrics| C[Prometheus :9090]
    B -->|Logs| D[Loki :3100]
    C --> E[Grafana :3000]
    D --> E

    style A fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style B fill:#f9ab00,stroke:#333,stroke-width:2px,color:#fff
    style C fill:#e6522c,stroke:#333,stroke-width:2px,color:#fff
    style D fill:#f46800,stroke:#333,stroke-width:2px,color:#fff
    style E fill:#f05a28,stroke:#333,stroke-width:2px,color:#fff
```

## Dashboard Preview

### Summary Statistics
![Summary Statistics](images/dashboard/01-dashboard-summary-stats.png)

### Time Series Analysis
![Time Series Analysis](images/dashboard/02-dashboard-time-series.png)

### Analysis & Efficiency
![Analysis and Efficiency](images/dashboard/03-dashboard-analysis-efficiency.png)

### Session Details
![Session Details](images/dashboard/04-dashboard-session-details.png)

### Development Activity
![Development Activity](images/dashboard/05-dashboard-dev-activity.png)

### Development Trends
![Development Trends](images/dashboard/06-dashboard-dev-trends.png)

## Prerequisites

- Docker and Docker Compose installed
- Claude Code CLI v2.1+ installed
- Port 3000, 3100, 4317, 8889, 9090 available

## Quick Start

### 1. Run Setup Script

```bash
./setup.sh
```

This automatically:
- Starts all services
- Configures Grafana data sources
- Imports the monitoring dashboard

### 2. Enable Telemetry

Edit `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4317"
  }
}
```

Restart Claude Code to apply changes.

### 3. View Dashboard

Open: http://localhost:3000/d/claude-code-monitoring

Generate some telemetry:

```bash
claude "test telemetry"
```

## What's Tracked

- **Token usage** - Input, output, cache reads/writes
- **API costs** - Per model (Sonnet, Haiku, etc.)
- **Session activity** - Active time, session count
- **Cache efficiency** - Cache hit rates
- **Development metrics** - Lines changed, commits, pull requests
- **Code editing** - Tool decisions and outcomes

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana | http://localhost:3000 | Main dashboard |
| Prometheus | http://localhost:9090 | Metrics query UI |
| Loki | http://localhost:3100 | Logs API |

## Common Commands

```bash
# Stop services (data preserved)
docker-compose down

# Stop and delete all data
docker-compose down -v

# View logs
docker-compose logs -f otel-collector

# Restart services
docker-compose restart

# Check status
docker-compose ps
```

## Data Persistence

Your data is **automatically saved** in Docker volumes:
- Metrics history (Prometheus)
- Log history (Loki)
- Dashboard settings (Grafana)

Data persists across restarts. To reset completely:
```bash
docker-compose down -v
./setup.sh
```

## Available Metrics

| Metric | Description |
|--------|-------------|
| `claude_code_cost_usage_USD_total` | Total cost in USD |
| `claude_code_token_usage_tokens_total` | Token count by type |
| `claude_code_active_time_seconds_total` | Active session time |
| `claude_code_session_count_total` | Number of sessions |
| `claude_code_lines_of_code_count_total` | Lines of code changed (added/removed) |
| `claude_code_pull_request_count_total` | Pull requests created via Claude Code |
| `claude_code_commit_count_total` | Git commits created via Claude Code |
| `claude_code_code_edit_tool_decision_total` | Code edit tool decisions (accept/reject) |

### Example Prometheus Queries

**Total spending:**
```promql
sum(claude_code_cost_usage_USD_total)
```

**Cache efficiency:**
```promql
sum(claude_code_token_usage_tokens_total{type="cacheRead"}) /
(sum(claude_code_token_usage_tokens_total{type="cacheRead"}) +
 sum(claude_code_token_usage_tokens_total{type="input"}))
```

**Cost per hour:**
```promql
rate(claude_code_cost_usage_USD_total[1h]) * 3600
```

## Troubleshooting

### No data appearing?

1. Verify telemetry is enabled:
   ```bash
   cat ~/.claude/settings.json
   ```
   Should show `CLAUDE_CODE_ENABLE_TELEMETRY: "1"`

2. Check services are running:
   ```bash
   docker-compose ps
   ```
   All should show "Up"

3. Check OTel Collector is receiving data:
   ```bash
   docker-compose logs otel-collector | grep -i received
   ```

4. Verify Prometheus is scraping:
   ```bash
   curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
   ```

### Port already in use?

Edit `docker-compose.yml` and change port mappings:
```yaml
ports:
  - "13000:3000"  # Use 13000 instead of 3000
```

### Colima-specific issues?

- Check Colima is running: `colima status`
- Verify Docker socket: `docker ps`
- Try restarting: `colima restart`

### Dashboard shows "No Data"?

1. Generate some telemetry: `claude "echo test"`
2. Wait 10-15 seconds for data to propagate
3. Check Prometheus has data: `curl -s http://localhost:8889/metrics | grep claude_code`

## Security Note

⚠️ This setup uses **anonymous admin access** in Grafana for ease of use. This is suitable for local development only. Do not expose these services to the internet.
