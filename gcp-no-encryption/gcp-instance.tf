data "google_compute_image" "ph-gcp-image" {
  project = var.gcp_image_project
  family  = var.gcp_image_family
}

resource "google_compute_address" "ph-public-ip" {
  name         = "${var.ph_prefix}-public-ip"
  project      = google_project.ph-project.project_id
  region       = var.gcp_region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  depends_on   = [google_project_service.ph-project-services]
}

locals {
  ssh_key           = trimspace(file(pathexpand(var.ssh_key_path)))
  ssh_key_formatted = length(split(" ", local.ssh_key)) == 3 ? local.ssh_key : "${local.ssh_key} ubuntu"
}

resource "google_compute_instance" "ph-instance" {
  name         = "${var.ph_prefix}-instance"
  zone         = "${var.gcp_region}-${var.gcp_zone}"
  machine_type = var.gcp_machine_type
  project      = google_project.ph-project.project_id
  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_key_formatted}"
    startup-script = templatefile(
      "${path.module}/scripts/startup.sh.tftpl",
      {
        project_url        = var.project_url
        docker_network     = var.docker_network
        docker_gw          = var.docker_gw
        docker_doh         = var.docker_doh
        docker_pihole      = var.docker_pihole
        docker_wireguard   = var.docker_wireguard
        wireguard_network  = var.wireguard_network
        doh_provider       = var.doh_provider
        dns_novpn          = var.dns_novpn
        gcp_project_prefix = var.ph_prefix
        gcp_project_suffix = random_string.ph-random.result
        wireguard_peers    = var.wireguard_peers
        vpn_traffic        = var.vpn_traffic
      }
    )
  }
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ph-gcp-image.self_link
      type  = "pd-standard"
      size  = "30"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.ph-subnetwork.self_link
    network_ip = var.gcp_instanceip
    access_config {
      nat_ip       = google_compute_address.ph-public-ip.address
      network_tier = "STANDARD"
    }
  }
  service_account {
    email  = google_service_account.ph-service-account.email
    scopes = ["cloud-platform", "storage-rw"]
  }
  allow_stopping_for_update = true
  depends_on                = [google_service_account_iam_policy.ph-account-service-iam-policy, google_storage_bucket.ph-bucket]
}
