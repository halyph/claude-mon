# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides a complete observability stack for monitoring Claude Code sessions. It uses OpenTelemetry (OTel) as the ingestion gateway, Prometheus for metrics storage, Loki for log aggregation, and Grafana for visualization.

## Architecture

The monitoring pipeline follows this flow:
```
Claude Code → OTLP (gRPC port 4317) → OTel Collector → {Prometheus, Loki} → Grafana
```

**Components:**
- **OTel Collector**: Gateway that receives telemetry via OTLP protocol and routes it to appropriate backends
  - Receives metrics and logs on port 4317 (OTLP gRPC)
  - Exposes Prometheus scrape endpoint on port 8889
- **Prometheus**: Time-series database for metrics (token usage, costs, etc.)
  - UI available at http://localhost:9090
  - Scrapes metrics from OTel Collector every 5 seconds
- **Loki**: Log aggregation system for conversation history and tool execution logs
  - API available at http://localhost:3100
- **Grafana**: Unified visualization dashboard
  - UI available at http://localhost:3000
  - Pre-configured with anonymous admin access for ease of use

## Common Commands

### Quick setup (automated)
```bash
./setup.sh
```
This script starts all services, configures Grafana data sources, and imports the dashboard.

### Start the monitoring stack (manual)
```bash
docker-compose up -d
```

### Stop the monitoring stack
```bash
docker-compose down
```

### View logs from all services
```bash
docker-compose logs -f
```

### View logs from a specific service
```bash
docker-compose logs -f [otel-collector|prometheus|loki|grafana]
```

### Restart a specific service
```bash
docker-compose restart [service-name]
```

### Check service status
```bash
docker-compose ps
```

## Configuration Files

- **docker-compose.yml**: Defines all services and their networking
- **config/otel-collector.yaml**: Configures OTel Collector receivers, exporters, and pipelines
  - Metrics pipeline: OTLP → Prometheus exporter
  - Logs pipeline: OTLP → Loki exporter + console logging
- **config/prometheus.yaml**: Configures Prometheus scrape targets
- **config/grafana/dashboards/**: Grafana dashboard definitions

## Making Configuration Changes

When modifying configuration files:
1. Edit the relevant YAML file
2. Restart the affected service: `docker-compose restart [service-name]`
3. For OTel Collector changes, verify the new config loads without errors: `docker-compose logs otel-collector`

## Ports Reference

- **4317**: OTel Collector OTLP gRPC endpoint (Claude Code sends data here)
- **8889**: OTel Collector Prometheus metrics endpoint
- **9090**: Prometheus UI and API
- **3100**: Loki API endpoint
- **3000**: Grafana dashboard UI
