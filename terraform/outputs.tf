output "worker_ip" {
  description = "IP address of the worker VM"
  value       = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  description = "IP address of the database VM"
  value       = libvirt_domain.db.network_interface[0].addresses[0]
}
