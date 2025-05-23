resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = var.vpc_network_name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_compute_global_address" "private_ip_range" {
  provider      = google-beta
  name          = "private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network_name
}


resource "google_sql_database_instance" "postgres_instance" {
  depends_on          = [google_service_networking_connection.private_vpc_connection]
  database_version    = "POSTGRES_15"
  name                = "postgres-instance"
  project             = var.project_id
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    activation_policy = "ALWAYS"
    availability_type = "ZONAL"

    backup_configuration {
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }

      enabled                        = true
      location                       = "asia"
      point_in_time_recovery_enabled = true
      start_time                     = "21:00"
      transaction_log_retention_days = 7
    }

    disk_autoresize       = true
    disk_autoresize_limit = 0
    disk_size             = 100
    disk_type             = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = true
      private_network = "projects/${var.project_id}/global/networks/${var.vpc_network_name}"
    }

    location_preference {
      zone = "${var.region}-b"
    }

    maintenance_window {
      update_track = "canary"
      day          = 7
    }

    pricing_plan = "PER_USE"
    tier         = "db-custom-2-8192"
  }
}

resource "google_sql_database" "dify_database" {
  name     = "dify"
  instance = google_sql_database_instance.postgres_instance.name
  project  = var.project_id

  depends_on = [google_sql_database_instance.postgres_instance]
}

resource "google_sql_database" "dify_plugin_database" {
  name     = "dify_plugin"
  instance = google_sql_database_instance.postgres_instance.name
  project  = var.project_id

  depends_on = [google_sql_database_instance.postgres_instance]
}

resource "google_sql_user" "dify_user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres_instance.name
  project  = var.project_id
  password_wo = var.db_password

  depends_on = [google_sql_database_instance.postgres_instance]
}
