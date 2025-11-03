# Alerting Configuration

# Contact Points (where alerts are sent)

# Email contact point
resource "grafana_contact_point" "email" {
  count = var.alert_email != "" ? 1 : 0

  name = "Email Alerts"

  email {
    addresses = [var.alert_email]
    subject   = "[${var.app_name}] {{ .GroupLabels.alertname }}"
  }
}

# Slack contact point
resource "grafana_contact_point" "slack" {
  count = var.alert_slack_webhook != "" ? 1 : 0

  name = "Slack Alerts"

  slack {
    url  = var.alert_slack_webhook
    text = <<-EOT
      {{ range .Alerts }}
        *Alert:* {{ .Labels.alertname }}
        *Summary:* {{ .Annotations.summary }}
        *Description:* {{ .Annotations.description }}
        *Severity:* {{ .Labels.severity }}
      {{ end }}
    EOT
  }
}

# Notification Policy (routing rules)
resource "grafana_notification_policy" "default" {
  group_by      = ["alertname", "grafana_folder"]
  contact_point = length(grafana_contact_point.email) > 0 ? grafana_contact_point.email[0].name : "grafana-default-email"

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  # Route critical alerts to Slack (if configured)
  dynamic "policy" {
    for_each = var.alert_slack_webhook != "" ? [1] : []
    content {
      matcher {
        label = "severity"
        match = "="
        value = "critical"
      }
      contact_point   = grafana_contact_point.slack[0].name
      group_by        = ["alertname"]
      group_wait      = "10s"
      group_interval  = "2m"
      repeat_interval = "1h"
    }
  }
}

# Alert Rule Groups

# High Error Rate Alert
resource "grafana_rule_group" "error_alerts" {
  name             = "${var.app_name} Error Alerts"
  folder_uid       = grafana_folder.app_monitoring.uid
  interval_seconds = 60

  rule {
    name      = "High Error Rate"
    condition = "C"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "sum(rate(http_requests_total{job=\"${var.app_name}\", status=~\"5..\"}[5m]))"
        refId        = "A"
        intervalMs   = 1000
        maxDataPoints = 43200
      })
    }

    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "sum(rate(http_requests_total{job=\"${var.app_name}\"}[5m]))"
        refId        = "B"
        intervalMs   = 1000
        maxDataPoints = 43200
      })
    }

    # Calculate error rate percentage
    data {
      ref_id = "C"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "math"
        expression = "(A / B) * 100"
        refId      = "C"
      })
    }

    # Threshold condition
    data {
      ref_id = "D"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type = "threshold"
        conditions = [
          {
            evaluator = {
              params = [5]  # Alert if error rate > 5%
              type   = "gt"
            }
            query = {
              params = ["C"]
            }
          }
        ]
        refId = "D"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "5m"

    annotations = {
      summary     = "High error rate detected for ${var.app_name}"
      description = "Error rate is {{ $values.C.Value }}% (threshold: 5%)"
    }

    labels = {
      severity = "critical"
      team     = "backend"
    }
  }
}

# High Response Time Alert
resource "grafana_rule_group" "performance_alerts" {
  name             = "${var.app_name} Performance Alerts"
  folder_uid       = grafana_folder.app_monitoring.uid
  interval_seconds = 60

  rule {
    name      = "High Response Time"
    condition = "B"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"${var.app_name}\"}[5m])) by (le))"
        refId        = "A"
        intervalMs   = 1000
        maxDataPoints = 43200
      })
    }

    data {
      ref_id = "B"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type = "threshold"
        conditions = [
          {
            evaluator = {
              params = [0.5]  # Alert if p95 > 500ms
              type   = "gt"
            }
            query = {
              params = ["A"]
            }
          }
        ]
        refId = "B"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "5m"

    annotations = {
      summary     = "High response time for ${var.app_name}"
      description = "P95 response time is {{ $values.A.Value }}s (threshold: 0.5s)"
    }

    labels = {
      severity = "warning"
      team     = "backend"
    }
  }

  # High CPU Usage Alert
  rule {
    name      = "High CPU Usage"
    condition = "B"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "rate(process_cpu_seconds_total{job=\"${var.app_name}\"}[5m]) * 100"
        refId        = "A"
        intervalMs   = 1000
        maxDataPoints = 43200
      })
    }

    data {
      ref_id = "B"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type = "threshold"
        conditions = [
          {
            evaluator = {
              params = [80]  # Alert if CPU > 80%
              type   = "gt"
            }
            query = {
              params = ["A"]
            }
          }
        ]
        refId = "B"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "10m"

    annotations = {
      summary     = "High CPU usage for ${var.app_name}"
      description = "CPU usage is {{ $values.A.Value }}% (threshold: 80%)"
    }

    labels = {
      severity = "warning"
      team     = "infrastructure"
    }
  }
}

# Service Down Alert
resource "grafana_rule_group" "availability_alerts" {
  name             = "${var.app_name} Availability Alerts"
  folder_uid       = grafana_folder.app_monitoring.uid
  interval_seconds = 30

  rule {
    name      = "Service Down"
    condition = "B"

    data {
      ref_id = "A"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "up{job=\"${var.app_name}\"}"
        refId        = "A"
        intervalMs   = 1000
        maxDataPoints = 43200
      })
    }

    data {
      ref_id = "B"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type = "threshold"
        conditions = [
          {
            evaluator = {
              params = [1]
              type   = "lt"
            }
            query = {
              params = ["A"]
            }
          }
        ]
        refId = "B"
      })
    }

    no_data_state  = "Alerting"
    exec_err_state = "Alerting"
    for            = "2m"

    annotations = {
      summary     = "${var.app_name} is down"
      description = "Service has been unavailable for more than 2 minutes"
    }

    labels = {
      severity = "critical"
      team     = "sre"
    }
  }
}

# Memory Usage Alert
resource "grafana_rule_group" "resource_alerts" {
  name             = "${var.app_name} Resource Alerts"
  folder_uid       = grafana_folder.app_monitoring.uid
  interval_seconds = 60

  rule {
    name      = "High Memory Usage"
    condition = "B"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "process_resident_memory_bytes{job=\"${var.app_name}\"} / 1024 / 1024 / 1024"
        refId        = "A"
        intervalMs   = 1000
        maxDataPoints = 43200
      })
    }

    data {
      ref_id = "B"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type = "threshold"
        conditions = [
          {
            evaluator = {
              params = [2]  # Alert if memory > 2GB
              type   = "gt"
            }
            query = {
              params = ["A"]
            }
          }
        ]
        refId = "B"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "10m"

    annotations = {
      summary     = "High memory usage for ${var.app_name}"
      description = "Memory usage is {{ $values.A.Value }}GB (threshold: 2GB)"
    }

    labels = {
      severity = "warning"
      team     = "infrastructure"
    }
  }
}
