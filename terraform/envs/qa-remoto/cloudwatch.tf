resource "aws_cloudwatch_log_group" "qa_remoto" {
  name              = "/aws/codebuild/spa-qa-remoto"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "spa-qa-remoto-logs"
  }
}
