# The fourth dev root (ADR-0022, amended 2026-10-05): the optional learning extras, applied only by `up --extras`. The default
# environment is lean; this root adds a workstation to log in to, reachable three ways (docs/guides/reaching-an-ec2-instance.md).
# It reads the network from the foundation root's state, so ../foundation must be applied first.
provider "aws" {
  region = var.region

  # Floci accepts any credentials. Static test keys, with the endpoints below, also mean this code can never
  # reach real AWS by accident, whatever is in ~/.aws.
  access_key = "test"
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Every service this root calls must be listed; an unlisted one would go to the real AWS endpoint.
  endpoints {
    ec2 = var.floci_endpoint
    iam = var.floci_endpoint
    s3  = var.floci_endpoint
    sts = var.floci_endpoint
  }

  default_tags {
    tags = {
      Project     = var.project
      Environment = "dev"
      ManagedBy   = "opentofu"
    }
  }
}

locals {
  name = "${var.project}-dev"
}

data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = "yaaf-dev-tfstate"
    key    = "foundation/terraform.tfstate"
    region = var.region

    endpoints = {
      s3 = var.floci_endpoint
    }
    use_path_style              = true
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}

# A key pair from the public key `up --extras` generates (.ssh/floci-dev in the repository). Only the public half ever reaches
# OpenTofu. Empty: no key pair, and the instance is reachable only through SSM or the dashboard terminal.
resource "aws_key_pair" "dev" {
  count = var.ssh_public_key == "" ? 0 : 1

  key_name   = "${local.name}-dev"
  public_key = var.ssh_public_key
}

# A small instance to log in to, three ways: the dashboard's terminal, SSH from your own terminal, and SSM Run Command.
# Real AMIs ship an SSH server; Floci's are minimal container images, so user data installs one, exactly as it would install
# anything else on first boot.
#
# Ubuntu 24.04 on arm64, not Floci's Amazon Linux 2023: that image exists only as x86_64, and on an arm64 Mac it runs under QEMU
# user-mode emulation, which lacks the seccomp support OpenSSH's sandbox needs (sshd logs `prctl(PR_SET_SECCOMP): Invalid
# argument` and drops every connection after key exchange). The arm64 image runs natively. A Graviton instance type to match.
module "workstation" {
  source = "../../../modules/ec2-instance"

  name          = "${local.name}-workstation"
  vpc_id        = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_id     = data.terraform_remote_state.foundation.outputs.public_subnet_ids[0]
  key_name      = one(aws_key_pair.dev[*].key_name)
  ami_id        = "ami-ubuntu2404-arm64"
  instance_type = "t4g.micro"

  # Floci publishes the SSH port on the host and does not enforce this range (see infra/README.md); real AWS would.
  ssh_ingress_cidrs = ["127.0.0.1/32"]

  user_data = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /var/log/user-data.log 2>&1
    apt-get install -y -qq openssh-server >> /var/log/user-data.log 2>&1
    mkdir -p /run/sshd
    ssh-keygen -A
    /usr/sbin/sshd
  EOT
}
