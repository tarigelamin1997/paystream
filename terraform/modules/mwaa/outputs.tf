output "environment_arn" {
  value = aws_mwaa_environment.main.arn
}

output "webserver_url" {
  value = aws_mwaa_environment.main.webserver_url
}
