output "instance_id" {
  value = aws_instance.this.id
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "role_name" {
  value = aws_iam_role.this.name
}
