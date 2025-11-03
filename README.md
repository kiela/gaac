# Grafana Infrastructure as Code

Professional Grafana configuration using Terraform. No manual clicking, no JSON tracking - pure infrastructure as code.

## What's Included

- **Dashboards**: Pre-configured dashboards with common application metrics
  - Overview dashboard with request rate, error rate, response time
  - Database metrics dashboard
  - System resource monitoring (CPU, memory, connections)
- **Alerts**: Production-ready alerting rules
  - High error rate detection
  - Performance degradation alerts
  - Service availability monitoring
  - Resource usage warnings
- **Data Sources**: Automated Prometheus/Mimir configuration
- **Contact Points**: Email and Slack notifications

## Prerequisites

1. **Terraform** >= 1.0
   ```bash
   brew install terraform  # macOS
   # or download from https://www.terraform.io/downloads
   ```

2. **Grafana** instance (local or remote)
   ```bash
   # Quick local setup with Docker
   docker run -d -p 3000:3000 --name=grafana grafana/grafana
   ```

3. **Grafana API Token** or admin credentials
   - Go to Grafana → Configuration → API Keys
   - Create new API key with Admin role
   - Or use default admin:admin for local testing

## Quick Start

### 1. Configure Your Environment

Copy the example configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:
```hcl
grafana_url  = "http://localhost:3000"
grafana_auth = "admin:admin"  # or "glsa_your_api_token"

prometheus_url  = "http://localhost:9090"
app_name        = "my-awesome-app"

# Optional: Alert notifications
alert_email         = "team@example.com"
alert_slack_webhook = "https://hooks.slack.com/services/xxx/yyy/zzz"
```

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the Grafana provider and sets up your workspace.

### 3. Preview Changes

```bash
terraform plan
```

Review what will be created. You should see:
- 1 data source (Prometheus)
- 1 folder
- 2 dashboards
- 4 rule groups with 7 alert rules
- Contact points (if configured)

### 4. Deploy

```bash
terraform apply
```

Type `yes` to confirm. Your dashboards and alerts will be created in seconds.

### 5. Access Your Dashboards

Open Grafana and navigate to:
- Dashboards → Browse → `{app_name} Monitoring` folder
- Alerting → Alert rules (to see your configured alerts)

## Project Structure

```
.
├── main.tf                    # Terraform & provider configuration
├── variables.tf               # Input variables definition
├── terraform.tfvars          # Your actual values (gitignored)
├── terraform.tfvars.example  # Example configuration
├── datasources.tf            # Prometheus/Mimir data source
├── dashboards.tf             # Dashboard definitions
├── alerts.tf                 # Alert rules & notifications
└── README.md                 # This file
```

## Customization Guide

### Adding Custom Metrics

Edit `dashboards.tf` and add a new panel:

```hcl
{
  id    = 99
  title = "My Custom Metric"
  type  = "timeseries"
  gridPos = {
    x = 0
    y = 30
    w = 12
    h = 8
  }
  targets = [
    {
      expr = "your_custom_metric{job=\"${var.app_name}\"}"
      legendFormat = "Custom"
      refId = "A"
      datasource = {
        type = var.prometheus_type
        uid  = grafana_data_source.prometheus.uid
      }
    }
  ]
}
```

### Creating New Alerts

Add to `alerts.tf`:

```hcl
resource "grafana_rule_group" "my_custom_alerts" {
  name             = "${var.app_name} Custom Alerts"
  folder_uid       = grafana_folder.app_monitoring.uid
  interval_seconds = 60

  rule {
    name      = "My Alert"
    condition = "B"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr  = "your_metric > 100"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      datasource_uid = "__expr__"
      model = jsonencode({
        type = "threshold"
        conditions = [{
          evaluator = {
            params = [100]
            type   = "gt"
          }
          query = { params = ["A"] }
        }]
        refId = "B"
      })
    }

    annotations = {
      summary     = "Alert triggered"
      description = "Metric exceeded threshold"
    }

    labels = {
      severity = "warning"
    }
  }
}
```

### Adding More Data Sources

Edit `datasources.tf`:

```hcl
resource "grafana_data_source" "loki" {
  type = "loki"
  name = "Loki"
  url  = "http://localhost:3100"
}

resource "grafana_data_source" "postgres" {
  type = "postgres"
  name = "PostgreSQL"
  url  = "localhost:5432"

  database_name = "mydb"
  username      = "readonly"

  secure_json_data_encoded = jsonencode({
    password = "your-password"
  })
}
```

## Metric Requirements

The default dashboards expect your application to expose these Prometheus metrics:

### HTTP Metrics
- `http_requests_total` - Counter with labels: `status`, `method`
- `http_request_duration_seconds` - Histogram

### System Metrics
- `process_cpu_seconds_total` - CPU usage
- `process_resident_memory_bytes` - Memory usage
- `process_start_time_seconds` - Process start time
- `go_goroutines` - Active goroutines (for Go apps)

### Database Metrics (optional)
- `db_connections_active`
- `db_connections_idle`
- `db_query_duration_seconds`

**Don't have these metrics yet?**
- Use [prometheus/client_golang](https://github.com/prometheus/client_golang) for Go
- Use [prometheus-client](https://github.com/prometheus/client_python) for Python
- Use [prom-client](https://github.com/siimon/prom-client) for Node.js

## Alert Configuration

### Configured Alerts

1. **High Error Rate** (Critical)
   - Triggers when 5xx errors > 5% of total requests
   - Evaluation: Every 1min, fires after 5min

2. **High Response Time** (Warning)
   - Triggers when p95 latency > 500ms
   - Evaluation: Every 1min, fires after 5min

3. **Service Down** (Critical)
   - Triggers when service is unreachable
   - Evaluation: Every 30s, fires after 2min

4. **High CPU Usage** (Warning)
   - Triggers when CPU > 80%
   - Evaluation: Every 1min, fires after 10min

5. **High Memory Usage** (Warning)
   - Triggers when memory > 2GB
   - Evaluation: Every 1min, fires after 10min

### Alert Routing

- **Critical alerts** → Slack (if configured) + Email
- **Warning alerts** → Email only
- Grouped by: `alertname`, `grafana_folder`
- Repeat interval: 4h (warnings), 1h (critical)

## Common Workflows

### Update Dashboard

1. Edit `dashboards.tf`
2. Run `terraform plan` to preview
3. Run `terraform apply` to deploy

### Test Alerts Locally

```bash
# Trigger high CPU alert
stress-ng --cpu 4 --timeout 15m

# Check alert status in Grafana
open http://localhost:3000/alerting/list
```

### Multiple Environments

Create separate tfvars files:

```bash
# Production
terraform apply -var-file="prod.tfvars"

# Staging
terraform apply -var-file="staging.tfvars"
```

### Import Existing Dashboards

```bash
# Get dashboard UID from Grafana
terraform import grafana_dashboard.existing <folder-id>:<dashboard-uid>

# Generate HCL from state
terraform show
```

## Advanced: Remote State

For team collaboration, use remote state:

```hcl
# Add to main.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "grafana/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Or use Terraform Cloud:
```hcl
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "grafana-monitoring"
    }
  }
}
```

## Troubleshooting

### "Error: authentication required"
- Check `grafana_auth` in terraform.tfvars
- Verify API token has Admin permissions
- Test: `curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/org`

### "Error: data source not found"
- Ensure Prometheus is running
- Verify `prometheus_url` is correct
- Test: `curl http://localhost:9090/api/v1/status/config`

### Alerts not firing
- Check Prometheus is scraping your app: `http://localhost:9090/targets`
- Verify metric names match your instrumentation
- Review evaluation interval in Grafana → Alerting → Alert rules

### Dashboard panels show "No data"
- Confirm your app exposes metrics at `/metrics` endpoint
- Check Prometheus targets are up
- Verify job label matches `var.app_name`

## Best Practices

1. **Use workspaces** for multiple environments
   ```bash
   terraform workspace new prod
   terraform workspace new staging
   ```

2. **Pin provider versions** in main.tf (already done)

3. **Keep secrets out of git**
   - terraform.tfvars is gitignored
   - Use environment variables: `TF_VAR_grafana_auth`
   - Or use secret management: Vault, AWS Secrets Manager

4. **Use modules** for repeated patterns
   ```hcl
   module "app_monitoring" {
     source   = "./modules/app-monitoring"
     app_name = "service-1"
   }
   ```

5. **Review plan before apply**
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

## Resources

- [Grafana Terraform Provider Docs](https://registry.terraform.io/providers/grafana/grafana/latest/docs)
- [Grafana Alerting Guide](https://grafana.com/docs/grafana/latest/alerting/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## Next Steps

1. **Customize for your app**: Update metric names and thresholds
2. **Add more dashboards**: Create domain-specific views
3. **Set up CI/CD**: Auto-deploy on git push
4. **Enable state locking**: Prevent concurrent modifications
5. **Add tests**: Use `terraform validate` and `tflint`

---

**Pro tip**: Use `terraform fmt` to auto-format your HCL files and `terraform validate` to catch syntax errors before applying.

Happy monitoring! 🚀
