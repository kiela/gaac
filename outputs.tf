# Outputs - useful information after deployment

output "grafana_url" {
  description = "URL of your Grafana instance"
  value       = var.grafana_url
}

output "folder_uid" {
  description = "UID of the monitoring folder"
  value       = grafana_folder.app_monitoring.uid
}

output "dashboard_urls" {
  description = "Direct links to created dashboards"
  value = {
    overview = "${var.grafana_url}/d/${grafana_dashboard.app_overview.uid}"
    database = "${var.grafana_url}/d/${grafana_dashboard.app_database.uid}"
  }
}

output "prometheus_datasource_uid" {
  description = "UID of the Prometheus data source"
  value       = grafana_data_source.prometheus.uid
}

output "alert_summary" {
  description = "Summary of configured alerts"
  value = {
    error_alerts        = "High Error Rate"
    performance_alerts  = "High Response Time, High CPU Usage"
    availability_alerts = "Service Down"
    resource_alerts     = "High Memory Usage"
  }
}

output "contact_points" {
  description = "Configured notification channels"
  value = {
    email_configured = var.alert_email != ""
    slack_configured = var.alert_slack_webhook != ""
  }
}
