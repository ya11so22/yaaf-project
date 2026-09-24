output "state_bucket" {
  description = "Bucket the foundation and cluster roots keep their state in (their backend blocks name it)."
  value       = aws_s3_bucket.state.bucket
}
