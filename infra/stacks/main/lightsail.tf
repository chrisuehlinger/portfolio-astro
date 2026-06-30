resource "aws_lightsail_static_ip" "cms" {
  name = "portfolio-cms-ip"
}

resource "aws_lightsail_instance" "cms" {
  name              = "portfolio-cms"
  availability_zone = var.lightsail_availability_zone
  blueprint_id      = var.lightsail_blueprint_id
  bundle_id         = var.lightsail_bundle_id
  user_data         = file("${path.module}/cloud-init/cms-user-data.sh")

  add_on {
    type          = "AutoSnapshot"
    snapshot_time = "06:00"
    status        = "Enabled"
  }

  tags = {
    Project = local.project
    Role    = "wordpress-cms"
  }
}

resource "aws_lightsail_static_ip_attachment" "cms" {
  static_ip_name = aws_lightsail_static_ip.cms.name
  instance_name  = aws_lightsail_instance.cms.name
}

resource "aws_lightsail_instance_public_ports" "cms" {
  instance_name = aws_lightsail_instance.cms.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidrs     = ["0.0.0.0/0"]
  }

  port_info {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
    cidrs     = ["0.0.0.0/0"]
  }

  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
    cidrs     = ["0.0.0.0/0"]
  }
}
