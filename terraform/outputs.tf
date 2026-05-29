output "worker_ip" {
  description = "IP address of the worker VM"
  value       = libvirt_domain.worker.devices.interfaces[0].wait_for_ip
}

output "db_ip" {
  description = "IP address of the database VM"
  value       = libvirt_domain.db.devices.interfaces[0].wait_for_ip
}
