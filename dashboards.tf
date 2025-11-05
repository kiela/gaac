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
            expr         = "sum(rate(http_server_requests_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]))"
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
            expr         = "sum(rate(http_server_requests_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\", status=~\"5..\"}[5m]))"
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
            expr = "histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le))"
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
            expr         = "system_cpu_usage{job=\"${var.app_name}\", instance=~\"$instance\"} * 100"
            legendFormat = "System CPU - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "process_cpu_usage{job=\"${var.app_name}\", instance=~\"$instance\"} * 100"
            legendFormat = "Process CPU - {{instance}}"
            refId        = "B"
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
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # JVM Memory Overview
      {
        id    = 5
        title = "JVM Memory Overview"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 8
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "jvm_memory_used_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"heap\"}"
            legendFormat = "Heap Used - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_memory_used_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"nonheap\"}"
            legendFormat = "Non-Heap Used - {{instance}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "bytes"
            color = {
              mode = "palette-classic"
            }
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
            expr         = "sum by (status) (rate(http_server_requests_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]))"
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

      # JVM Thread Count
      {
        id    = 7
        title = "JVM Thread Count"
        type  = "stat"
        gridPos = {
          x = 0
          y = 24
          w = 12
          h = 6
        }
        targets = [
          {
            expr = "sum(jvm_threads_live{job=\"${var.app_name}\", instance=~\"$instance\"})"
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
                { value = 200, color = "yellow" },
                { value = 500, color = "red" }
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
      },

      # Row 3: Average Response Time
      {
        id    = 9
        title = "Average Response Time"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 30
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "rate(http_server_requests_seconds_sum{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]) / rate(http_server_requests_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])"
            legendFormat = "Avg Response Time"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Response Time Percentiles
      {
        id    = 10
        title = "Response Time Percentiles"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 30
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "histogram_quantile(0.50, sum(rate(http_server_requests_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le))"
            legendFormat = "p50"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "histogram_quantile(0.90, sum(rate(http_server_requests_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le))"
            legendFormat = "p90"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le))"
            legendFormat = "p95"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le))"
            legendFormat = "p99"
            refId        = "D"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Row 4: JVM Heap Memory
      {
        id    = 11
        title = "JVM Heap Memory Usage"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 38
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "jvm_memory_used_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"heap\"}"
            legendFormat = "Used - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_memory_max_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"heap\"}"
            legendFormat = "Max - {{instance}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_memory_committed_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"heap\"}"
            legendFormat = "Committed - {{instance}}"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "bytes"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # JVM Non-Heap Memory
      {
        id    = 12
        title = "JVM Non-Heap Memory Usage"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 38
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "jvm_memory_used_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"nonheap\"}"
            legendFormat = "Used - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_memory_max_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"nonheap\"}"
            legendFormat = "Max - {{instance}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_memory_committed_bytes{job=\"${var.app_name}\", instance=~\"$instance\", area=\"nonheap\"}"
            legendFormat = "Committed - {{instance}}"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "bytes"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Row 5: GC Pause Time
      {
        id    = 13
        title = "GC Pause Time"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 46
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "rate(jvm_gc_pause_seconds_sum{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])"
            legendFormat = "{{action}} - {{cause}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # GC Count
      {
        id    = 14
        title = "GC Count Rate"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 46
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "rate(jvm_gc_pause_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])"
            legendFormat = "{{action}} - {{cause}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Row 6: Thread Details
      {
        id    = 15
        title = "JVM Thread Details"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 54
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "jvm_threads_live{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Live Threads - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_threads_daemon{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Daemon Threads - {{instance}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jvm_threads_peak{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Peak Threads - {{instance}}"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Thread States
      {
        id    = 16
        title = "Thread States"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 54
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "jvm_threads_states{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "{{state}} - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
          }
        }
        options = {
          legend = {
            displayMode = "table"
            placement   = "right"
          }
        }
      },

      # Row 7: HikariCP Connection Pool
      {
        id    = 17
        title = "Database Connection Pool (HikariCP)"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 62
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "hikaricp_connections_active{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Active - {{pool}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "hikaricp_connections_idle{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Idle - {{pool}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "hikaricp_connections{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Total - {{pool}}"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Connection Pool Wait Time
      {
        id    = 18
        title = "Connection Pool Acquire Time (p95)"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 62
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "histogram_quantile(0.95, sum(rate(hikaricp_connections_acquire_seconds_bucket{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) by (le, pool))"
            legendFormat = "{{pool}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Row 8: Tomcat Threads
      {
        id    = 19
        title = "Tomcat Thread Pool"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 70
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "tomcat_threads_current_threads{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Current - {{name}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "tomcat_threads_busy_threads{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Busy - {{name}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "tomcat_threads_config_max_threads{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Max - {{name}}"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Jetty Thread Pool
      {
        id    = 20
        title = "Jetty Thread Pool"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 70
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "jetty_threads_current{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Current - {{type}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jetty_threads_busy{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Busy"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "jetty_threads_config_max{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Max"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      # Row 9: Request Rate by URI
      {
        id    = 21
        title = "Request Rate by URI"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 78
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "sum by (uri) (rate(http_server_requests_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]))"
            legendFormat = "{{uri}}"
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
            displayMode = "table"
            placement   = "right"
            calcs       = ["mean", "lastNotNull"]
          }
        }
      },

      # Response Time by URI
      {
        id    = 22
        title = "Avg Response Time by URI"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 78
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "sum by (uri) (rate(http_server_requests_seconds_sum{job=\"${var.app_name}\", instance=~\"$instance\"}[5m])) / sum by (uri) (rate(http_server_requests_seconds_count{job=\"${var.app_name}\", instance=~\"$instance\"}[5m]))"
            legendFormat = "{{uri}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            color = {
              mode = "palette-classic"
            }
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

      # Row 10: Class Loading
      {
        id    = 23
        title = "JVM Classes Loaded"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 86
          w = 24
          h = 8
        }
        targets = [
          {
            expr         = "jvm_classes_loaded{job=\"${var.app_name}\", instance=~\"$instance\"}"
            legendFormat = "Loaded - {{instance}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
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
        title = "Database Connection Pool (HikariCP)"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 0
          w = 12
          h = 8
        }
        targets = [
          {
            expr         = "hikaricp_connections_active{job=\"${var.app_name}\"}"
            legendFormat = "Active - {{pool}}"
            refId        = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "hikaricp_connections_idle{job=\"${var.app_name}\"}"
            legendFormat = "Idle - {{pool}}"
            refId        = "B"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "hikaricp_connections{job=\"${var.app_name}\"}"
            legendFormat = "Total - {{pool}}"
            refId        = "C"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          },
          {
            expr         = "hikaricp_connections_pending{job=\"${var.app_name}\"}"
            legendFormat = "Pending - {{pool}}"
            refId        = "D"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      {
        id    = 2
        title = "Connection Acquire Time (p95)"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 0
          w = 12
          h = 8
        }
        targets = [
          {
            expr = "histogram_quantile(0.95, sum(rate(hikaricp_connections_acquire_seconds_bucket{job=\"${var.app_name}\"}[5m])) by (le, pool))"
            legendFormat = "{{pool}}"
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
            color = {
              mode = "palette-classic"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "green" },
                { value = 0.1, color = "yellow" },
                { value = 0.5, color = "red" }
              ]
            }
          }
        }
      },

      {
        id    = 3
        title = "Connection Usage Rate"
        type  = "timeseries"
        gridPos = {
          x = 0
          y = 8
          w = 12
          h = 8
        }
        targets = [
          {
            expr = "rate(hikaricp_connections_usage_seconds_sum{job=\"${var.app_name}\"}[5m]) / rate(hikaricp_connections_usage_seconds_count{job=\"${var.app_name}\"}[5m])"
            legendFormat = "Avg Usage - {{pool}}"
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
            color = {
              mode = "palette-classic"
            }
          }
        }
      },

      {
        id    = 4
        title = "Connection Timeouts"
        type  = "timeseries"
        gridPos = {
          x = 12
          y = 8
          w = 12
          h = 8
        }
        targets = [
          {
            expr = "rate(hikaricp_connections_timeout_total{job=\"${var.app_name}\"}[5m])"
            legendFormat = "Timeouts - {{pool}}"
            refId = "A"
            datasource = {
              type = var.prometheus_type
              uid  = grafana_data_source.prometheus.uid
            }
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "green" },
                { value = 0.01, color = "yellow" },
                { value = 0.1, color = "red" }
              ]
            }
          }
        }
      }
    ]
  })
}
