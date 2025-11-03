variable "grafana_url" {
  description = "Grafana instance URL"
  type        = string
}

variable "grafana_auth" {
  description = "Grafana API token or username:password"
  type        = string
  sensitive   = true
}

variable "prometheus_url" {
  description = "Prometheus data source URL"
  type        = string
  default     = "http://localhost:9090"
}

variable "prometheus_type" {
  description = "Type of Prometheus data source (prometheus or mimir)"
  type        = string
  default     = "prometheus"
}

variable "app_name" {
  description = "Application name for dashboards and alerts"
  type        = string
  default     = "my-application"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

variable "alert_slack_webhook" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = ""
  sensitive   = true
}
