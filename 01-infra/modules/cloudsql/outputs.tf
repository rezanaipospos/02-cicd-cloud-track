output "instance_name" {
  description = "Nama instance CloudSQL."
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Connection name CloudSQL (format: project:region:instance) yang digunakan oleh Cloud SQL Auth Proxy/Connector."
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip_address" {
  description = "Private IP address dari instance CloudSQL."
  value       = google_sql_database_instance.main.private_ip_address
}
