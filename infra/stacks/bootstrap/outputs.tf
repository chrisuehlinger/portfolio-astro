output "state_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "backend_example" {
  value = <<EOT
bucket       = "${aws_s3_bucket.state.bucket}"
region       = "${var.aws_region}"
use_lockfile = true
encrypt      = true
EOT
}
