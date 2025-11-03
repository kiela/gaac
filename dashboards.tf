# Dashboards Configuration

# Create a folder for organizing dashboards
resource "grafana_folder" "app_monitoring" {
  title = "${var.app_name} Monitoring"
}

# Main application dashboard
resource "grafana_dashboard" "app_overview" {
  folder = grafana_folder.app_monitoring.id

  config_json = jsonencode({
    title   = "${var.app_name} - Overview"
    tags    = ["application", "overview", var.app_name]
    timezone = "browser"

    # Time picker settings
    time = {
      from = "now-6h"
      to   = "now"
    }

    # Refresh interval
    refresh = "30s"

    # Template variables for filtering
    templating = {
      list = [
        {
          name       = "instance"
          type       = "query"
          datasource = {
            type = var.prometheus_type
            uid  = grafana_data_source.prometheus.uid
          }
          query      = "label_values(up{job=\"${var.app_name}\"}, instance)"
          refresh    = 1
          multi      = true
          includeAll = true
        }
      ]
    }

    panels = [
      # Row 1: Key Metrics
      {
        id    = 1
        title = "Request Rate"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 0
          w = 8
          h = 8
        }
        targets = [
          {
            expr         = "sum(rate(http_requests_total{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]))"
            legendFormat = "Requests/sec"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            color = {
              mode = "palette-classic"
            }
          }
        }
        options = {
          legend = {
            displayMode = "list"
            placement   = "bottom"
          }
        }
      },

      # Error Rate
      {
        id    = 2
        title = "Error Rate"
        type  = "timeseries"
        gridPos = {
          x = 8
          y = 0
          w = 8
          h = 8
        }
        targets = [
          {
            expr         = "sum(rate(http_requests_total{job=\"${var.app_name}\", instance=~\"$instance\", status=~\"5..\"}[5m]))"
            legendFormat = "5xx errors/sec"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "green" },
                { value = 0.1, color = "yellow" },
                { value = 1, color = "red" }
              ]
            }
          }
        }
      },

      # Response Time (p95)
      {
        id    = 3
        title = "Response Time (p95)"
        type  = "gauge"
        gridPos = {
          x = 16
          y = 0
          w = 8
          h = 8
        }
        targets = [
          {
            expr = "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le))"
            refId = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            max  = 1
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "green" },
                { value = 0.3, color = "yellow" },
                { value = 0.5, color = "red" }
              ]
            }
          }
        }
        options = {
          showThresholdLabels = false
          showThresholdMarkers = true
        }
      },

      # Row 2: System Metrics
      {
        id    = 4
        title = "CPU Usage"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 8
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "rate(process_cpu_seconds_total{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]) * 100"
            legendFormat = "{{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "percent"
            max  = 100
          }
        }
      },

      # Memory Usage
      {
        id    = 5
        title = "Memory Usage"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 8
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "process_resident_memory_bytes{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "{{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "bytes"
          }
        }
      },

      # Row 3: Status Codes
      {
        id    = 6
        title = "HTTP Status Codes"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 16
          w = 24
          h = 8
        }
        targets = [
          {
            expr         = "sum by (status) (rate(http_requests_total{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]))"
            legendFormat = "{{status}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "reqps"
          }
        }
        options = {
          legend = {
            displayMode = "table"
            placement   = "right"
            calcs       = ["mean", "lastNotNull", "max"]
          }
        }
      },

      # Active connections/goroutines
      {
        id    = 7
        title = "Active Connections"
        type  = "stat"
        gridPos = {
          x = 0
          y = 24
          w = 12
          h = 6
        }
        targets = [
          {
            expr = "sum(go_goroutines{job=\"${var.app_name}\", instance=~\"$instance\"})"
            refId = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "green" },
                { value = 1000, color = "yellow" },
                { value = 5000, color = "red" }
              ]
            }
          }
        }
      },

      # Uptime
      {
        id    = 8
        title = "Uptime"
        type  = "stat"
        gridPos = {
          x = 12
          y = 24
          w = 12
          h = 6
        }
        targets = [
          {
            expr = "time() - process_start_time_seconds{job=\"${var.app_name}\", instance=~\"$instance\"}"
            refId = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
          }
        }
      }
    ]
  })
}

# Example: Database-specific dashboard
resource "grafana_dashboard" "app_database" {
  folder = grafana_folder.app_monitoring.id

  config_json = jsonencode({
    title   = "${var.app_name} - Database Metrics"
    tags    = ["database", var.app_name]
    timezone = "browser"

    time = {
      from = "now-6h"
      to   = "now"
    }

    panels = [
      {
        id    = 1
        title = "Database Connection Pool"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 0
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "db_connections_active{job=\"${var.app_name}\"}"
            legendFormat = "Active"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "db_connections_idle{job=\"${var.app_name}\"}"
            legendFormat = "Idle"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
      },

      {
        id    = 2
        title = "Query Duration (p95)"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 0
          w = 12
          h = 8
        }
        targets = [
          {
            expr = "histogram_quantile(0.95, sum(rate(db_query_duration_seconds_bucket{job=\"${var.app_name}\"}[5m])) by (le, query_type))"
            legendFormat = "{{query_type}}"
            refId = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
          }
        }
      }
    ]
  })
}
