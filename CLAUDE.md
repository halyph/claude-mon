# CLAUDE.md

This file provides technical guidance to Claude Code when working with this repository.

## Project Overview

Observability stack for monitoring Claude Code sessions via OpenTelemetry, Prometheus, Loki, and Grafana.

## Repository Structure

```
claude-mon/
├── setup.sh                                     # Automated setup (starts services, configures Grafana via API)
├── docker-compose.yml                           # Service orchestration with persistent volumes
└── config/                                      # All configuration files
    ├── otel-collector.yaml                      # OTel: receives OTLP on :4317, exports to Prometheus/Loki
    ├── prometheus.yaml                          # Prometheus: scrapes OTel :8889 every 5s
    └── grafana/dashboards/
        └── claude-code-monitoring.json          # Dashboard with 16 panels (costs, tokens, cache, LOC, commits, etc.)
```

## Architecture

**Data Flow:**
```
Claude Code → OTLP gRPC :4317 → OTel Collector → Prometheus :9090 (metrics)
                                                → Loki :3100 (logs)
                                                ↓
                                            Grafana :3000 (visualization)
```

**Components:**
1. **OTel Collector** (otel/opentelemetry-collector-contrib)
   - Receives: OTLP gRPC on :4317
   - Exports: Prometheus metrics on :8889, Loki logs via OTLP HTTP
   - Config: `config/otel-collector.yaml`
   - Pipelines: metrics (otlp→prometheus), logs (otlp→loki+debug)

2. **Prometheus** (prom/prometheus)
   - Scrapes: OTel Collector :8889 every 5s
   - Storage: `prometheus-data` volume at `/prometheus`
   - Config: `config/prometheus.yaml`

3. **Loki** (grafana/loki)
   - Receives: Logs from OTel Collector via OTLP HTTP
   - Storage: `loki-data` volume at `/loki`
   - Uses: Default local config

4. **Grafana** (grafana/grafana)
   - Storage: `grafana-data` volume at `/var/lib/grafana`
   - Auth: Anonymous admin enabled (local dev only)
   - Config: Via `setup.sh` using Grafana API
   - Dashboards: Two pre-configured dashboards (metrics + logs)

## Data Persistence

All historical data preserved via Docker named volumes:
- `prometheus-data`: Metrics time-series
- `loki-data`: Log streams
- `grafana-data`: Dashboards, data sources, settings

**Lifecycle:**
- `docker-compose down`: Volumes persist
- `docker-compose down -v`: Volumes deleted

## Setup Script (`setup.sh`)

Automates full stack initialization:
1. Starts services via `docker-compose up -d`
2. Waits for Grafana health endpoint
3. Configures data sources via Grafana API with **fixed UIDs**:
   - Prometheus: `http://prometheus:9090` (UID: `prometheus-claude-code`, default)
   - Loki: `http://loki:3100` (UID: `loki-claude-code`)
4. Dynamically updates dashboard datasource references
5. Imports dashboards:
   - Metrics dashboard: `config/grafana/dashboards/claude-code-monitoring.json`
   - Logs dashboard: `config/grafana/dashboards/claude-code-logs.json`
6. Returns dashboard URLs and next steps

**Datasource UID Strategy:**
- Fixed UIDs prevent "datasource not found" errors on fresh installations
- Dashboard JSON uses placeholders (`PROMETHEUS_UID`, `LOKI_UID`)
- Setup script replaces placeholders with fixed UIDs before import
- This ensures dashboard works immediately without manual configuration

**Error handling:**
- Exits with status 1 if dashboard file not found
- Validates API response for successful import

## Metrics Exported by Claude Code

> 📖 **Official Documentation**: [Claude Code Monitoring & Usage](https://code.claude.com/docs/en/monitoring-usage.md)

When `CLAUDE_CODE_ENABLE_TELEMETRY=1`, Claude Code exports the following metrics:

**Core Usage Metrics:**
- `claude_code.cost.usage` → Cost by model, session (USD)
- `claude_code.token.usage` → Tokens by type (input/output/cacheRead/cacheCreation)
- `claude_code.active_time.total` → Session duration by type (cli/user)
- `claude_code.session.count` → Session counter

**Development Activity Metrics:**
- `claude_code.lines_of_code.count` → Lines changed by type (added/removed)
- `claude_code.pull_request.count` → Pull requests created
- `claude_code.commit.count` → Git commits created
- `claude_code.code_edit_tool.decision` → Code edit decisions (accept/reject by tool, language, source)

**Standard Labels:** `model`, `session_id`, `terminal_type`, `user_id`, `type`

Note: Prometheus converts metric names (`.` → `_`, appends `_total` for counters)

## Grafana Dashboards

### Metrics Dashboard (`claude-code-monitoring`)

URL: `http://localhost:3000/d/claude-code-monitoring`

The metrics dashboard includes 16 panels across multiple categories:

**Summary Stats (Row 1):**
1. Total Cost (USD) - Current session/total cost
2. Total Tokens Used - Aggregate token count
3. Total Active Time - Session duration in seconds
4. Total Sessions - Session counter

**Time Series Charts (Row 2):**
5. Cost by Model - Cost trends per model over time
6. Token Usage by Type - Token consumption by type (input/output/cache) over time

**Analysis Panels (Row 3):**
7. Cost Distribution by Model - Pie chart showing cost breakdown
8. Cache Hit Rate - Gauge showing cache effectiveness (cacheRead / (cacheRead + input))
9. Active Time by Type - Bar chart of user vs CLI time

**Details Table (Row 4):**
10. Session Details - Table with session_id, model, terminal, and cost

**Development Activity (Row 5):**
11. Total Lines Changed - Sum of added + removed lines
12. Pull Requests Created - PR counter
13. Commits Created - Commit counter
14. Code Edit Decisions - Total accept/reject decisions

**Development Trends (Row 6):**
15. Lines of Code Changes - Time series of added vs removed lines
16. Code Edit Tool Decisions - Stacked time series of tool decisions by type and outcome

### Logs Dashboard (`claude-code-logs`)

URL: `http://localhost:3000/d/claude-code-logs`

The logs dashboard includes 13 panels focused on log analysis:

**Log Overview (Row 1):**
1. Total Log Entries - Aggregate count of all log entries
2. Active Sessions - Number of unique sessions with logs
3. Current Log Rate - Real-time logs/second metric
4. Logs by Session - Pie chart showing log distribution per session

**Log Stream (Row 2):**
5. All Logs (Real-time) - Live streaming log viewer with full details

**Log Analysis (Row 3):**
6. Log Volume Over Time - Time series of log rate
7. Log Rate by Session - Stacked time series per session

**Session Details (Row 4):**
8. Sessions Summary - Table with session ID, model, and log count
9. Log Activity by Model - Bar chart showing log volume by Claude model

**Features:**
- Real-time log streaming with 5-second refresh
- LogQL query support for advanced filtering
- Session-level log aggregation and analysis
- Model-based log categorization
- Automatic label extraction from OTLP resource attributes

## Configuration Changes

When modifying configs:
1. Edit YAML in `config/` directory
2. Restart affected service: `docker-compose restart [service-name]`
3. Verify logs: `docker-compose logs [service-name]`

**Key files to update:**
- OTel pipelines: `config/otel-collector.yaml`
- Scrape intervals: `config/prometheus.yaml`
- Dashboard panels: `config/grafana/dashboards/*.json`

## Port Mappings

| Port | Service | Purpose |
|------|---------|---------|
| 4317 | OTel Collector | OTLP gRPC ingestion |
| 8889 | OTel Collector | Prometheus metrics endpoint |
| 9090 | Prometheus | Query UI and API |
| 3100 | Loki | Log API |
| 3000 | Grafana | Dashboard UI |

## Important Notes

- Grafana anonymous auth is enabled (development only)
- OTel Collector uses contrib image for Loki exporter
- Dashboard UIDs:
  - Metrics: `claude-code-monitoring`
  - Logs: `claude-code-logs`
- Datasource UIDs are fixed for reproducibility:
  - Prometheus: `prometheus-claude-code`
  - Loki: `loki-claude-code`
- No traces pipeline (Claude Code doesn't export traces)
- Both dashboards auto-refresh every 5 seconds
