# Grafana Infrastructure as Code for Java Applications

Professional Grafana configuration using Terraform for Java applications with Micrometer metrics. No manual clicking, no JSON tracking - pure infrastructure as code.

## What's Included

- **Dashboards**: Comprehensive dashboards optimized for Java/Micrometer metrics
  - **Application Overview**: Request rate, error rate, response time (avg, p50, p90, p95, p99)
  - **JVM Metrics**: Heap/non-heap memory, garbage collection, thread states, class loading
  - **Database Monitoring**: HikariCP connection pool metrics, acquire times, timeouts
  - **Application Server**: Tomcat/Jetty thread pool monitoring
  - **Per-endpoint Metrics**: Request rates and response times by URI
  - **System Resources**: CPU and memory usage
- **Alerts**: Production-ready alerting rules for Java applications
  - HTTP error rate and response time degradation
  - JVM heap memory exhaustion warnings
  - High GC pause time alerts
  - Database connection pool exhaustion
  - CPU usage monitoring
  - Service availability checks
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
- 2 dashboards (Application Overview + Database Metrics)
- 4 rule groups with 7 alert rules
- Contact points (if configured)

The dashboards include:
- **24 panels** covering HTTP metrics, JVM memory, GC, threads, connection pools, and more
- **Response time percentiles** (p50, p90, p95, p99)
- **Per-endpoint breakdown** for requests and latency
- **HikariCP connection pool** monitoring
- **Tomcat/Jetty thread pool** metrics

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

This monitoring setup is designed for **Java applications using Micrometer** to export Prometheus metrics. Micrometer is the metrics facade used by Spring Boot and many other Java frameworks.

### Required Micrometer Metrics

#### HTTP Server Metrics
- `http_server_requests_seconds_count` - Request counter with labels: `status`, `method`, `uri`
- `http_server_requests_seconds_sum` - Total request duration
- `http_server_requests_seconds_bucket` - Request duration histogram

#### JVM Memory Metrics
- `jvm_memory_used_bytes{area="heap"}` - Heap memory usage
- `jvm_memory_used_bytes{area="nonheap"}` - Non-heap memory usage
- `jvm_memory_max_bytes` - Maximum memory
- `jvm_memory_committed_bytes` - Committed memory

#### JVM Garbage Collection
- `jvm_gc_pause_seconds_count` - GC event count
- `jvm_gc_pause_seconds_sum` - Total GC pause time
- Labels: `action`, `cause`

#### JVM Thread Metrics
- `jvm_threads_live` - Live thread count
- `jvm_threads_daemon` - Daemon thread count
- `jvm_threads_peak` - Peak thread count
- `jvm_threads_states` - Thread count by state

#### System Metrics
- `system_cpu_usage` - System-wide CPU usage
- `process_cpu_usage` - Process CPU usage
- `process_start_time_seconds` - Process start time
- `jvm_classes_loaded` - Loaded class count

#### Database Connection Pool (HikariCP)
- `hikaricp_connections_active` - Active connections
- `hikaricp_connections_idle` - Idle connections
- `hikaricp_connections` - Total connections
- `hikaricp_connections_pending` - Pending connection requests
- `hikaricp_connections_acquire_seconds_bucket` - Connection acquire time histogram
- `hikaricp_connections_usage_seconds` - Connection usage duration
- `hikaricp_connections_timeout_total` - Connection timeout counter

#### Application Server Metrics (Optional)

**Tomcat:**
- `tomcat_threads_current_threads`
- `tomcat_threads_busy_threads`
- `tomcat_threads_config_max_threads`

**Jetty:**
- `jetty_threads_current`
- `jetty_threads_busy`
- `jetty_threads_config_max`

### Setting Up Micrometer in Your Java Application

#### Spring Boot (Automatic)

Add Micrometer registry to your `pom.xml`:
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

Or `build.gradle`:
```gradle
implementation 'io.micrometer:micrometer-registry-prometheus'
```

Enable metrics endpoint in `application.yml`:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    enable:
      jvm: true
      process: true
      system: true
      tomcat: true
      hikaricp: true
```

Metrics will be available at: `http://your-app:8080/actuator/prometheus`

#### Plain Java (Manual Setup)

```java
// Add to your main class
PrometheusMeterRegistry prometheusRegistry = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);

// Expose metrics endpoint (using Spark, Javalin, etc.)
get("/metrics", (req, res) -> {
    res.type("text/plain");
    return prometheusRegistry.scrape();
});

// Bind JVM metrics
new ClassLoaderMetrics().bindTo(prometheusRegistry);
new JvmMemoryMetrics().bindTo(prometheusRegistry);
new JvmGcMetrics().bindTo(prometheusRegistry);
new JvmThreadMetrics().bindTo(prometheusRegistry);
```

### Prometheus Configuration

Add your Java application to Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'my-java-app'
    metrics_path: '/actuator/prometheus'  # or /metrics
    static_configs:
      - targets: ['localhost:8080']
```

## Alert Configuration

### Configured Alerts

1. **High Error Rate** (Critical)
   - Triggers when 5xx errors > 5% of total requests
   - Evaluation: Every 1min, fires after 5min
   - Team: backend

2. **High Response Time** (Warning)
   - Triggers when p95 latency > 500ms
   - Evaluation: Every 1min, fires after 5min
   - Team: backend

3. **Service Down** (Critical)
   - Triggers when service is unreachable
   - Evaluation: Every 30s, fires after 2min
   - Team: sre

4. **High CPU Usage** (Warning)
   - Triggers when process CPU usage > 80%
   - Evaluation: Every 1min, fires after 10min
   - Team: infrastructure

5. **High JVM Heap Memory Usage** (Warning)
   - Triggers when heap usage > 85% of max
   - Evaluation: Every 1min, fires after 5min
   - Team: backend

6. **High GC Pause Time** (Warning)
   - Triggers when average GC pause > 100ms
   - Evaluation: Every 1min, fires after 5min
   - Team: backend

7. **Database Connection Pool Near Exhaustion** (Critical)
   - Triggers when active connections > 90% of pool size
   - Evaluation: Every 1min, fires after 2min
   - Team: backend

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
