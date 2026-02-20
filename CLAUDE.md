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
        └── claude-code-monitoring.json          # Dashboard with 10 panels (costs, tokens, cache, etc.)
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
3. Configures data sources via Grafana API:
   - Prometheus: `http://prometheus:9090` (default)
   - Loki: `http://loki:3100`
4. Imports dashboard from `config/grafana/dashboards/claude-code-monitoring.json`
5. Returns dashboard URL and next steps

**Error handling:**
- Exits with status 1 if dashboard file not found
- Validates API response for successful import

## Metrics Exported by Claude Code

When `CLAUDE_CODE_ENABLE_TELEMETRY=1`:
- `claude_code_cost_usage_USD_total`: Cost by model, session
- `claude_code_token_usage_tokens_total`: Tokens by type (input/output/cacheRead/cacheCreation)
- `claude_code_active_time_seconds_total`: Session duration by type (cli/user)
- `claude_code_session_count_total`: Session counter

Labels: `model`, `session_id`, `terminal_type`, `user_id`, `type`

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
- Dashboard UID: `claude-code-monitoring`
- No traces pipeline (Claude Code doesn't export traces)
