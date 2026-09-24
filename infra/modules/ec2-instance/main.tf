# One EC2 instance set up the way AWS recommends for a shell you log in to (ADR-0022): reachable over SSH from a
# narrow source range, and reachable with no open port at all through AWS Systems Manager.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# The instance's own identity. AmazonSSMManagedInstanceCore is what lets the SSM agent register the instance, so
# Run Command and Session Manager work without SSH. It is required on real AWS; Floci does not check it.
resource "aws_iam_role" "this" {
  name               = "${var.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance"
  role = aws_iam_role.this.name
  tags = var.tags

  # Floci does not implement ListInstanceProfileTags (checked with the AWS CLI against 2.1.0), so the provider can
  # never read this resource's tags back and would report drift on every plan. Tags are still set on create. On
  # real AWS, delete this block.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-instance"
  description = "SSH from a narrow range; all outbound"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-instance" })
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_ingress_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "SSH"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound (package installs, SSM, AWS APIs)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name
  key_name               = var.key_name
  user_data              = var.user_data

  # A changed script only runs on a new instance, so replace the instance rather than silently ignore the change.
  user_data_replace_on_change = true

  # IMDSv2 only: the metadata service answers only requests that carry a session token, which blocks the
  # server-side request forgery attacks that IMDSv1 allows.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, { Name = var.name })

  depends_on = [aws_iam_role_policy_attachment.ssm]
}
