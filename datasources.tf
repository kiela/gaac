# Data Sources Configuration

resource "grafana_data_source" "prometheus" {
  type = var.prometheus_type
  name = "Prometheus"
  url  = var.prometheus_url

  json_data_encoded = jsonencode({
    httpMethod    = "POST"
    timeInterval  = "30s"
  })
}

# Example: Additional data source for Loki (logs)
# Uncomment if you have Loki for logs
# resource "grafana_data_source" "loki" {
#   type = "loki"
#   name = "Loki"
#   url  = "http://localhost:3100"
#
#   json_data_encoded = jsonencode({
#     maxLines = 1000
#   })
# }
