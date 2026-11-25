output "aws_region" {
  description = "AWS region of the remote QA environment."
  value       = var.aws_region
}

output "codebuild_project_name" {
  description = "Name of the remote QA CodeBuild project."
  value       = aws_codebuild_project.qa_remoto.name
}

output "codebuild_project_arn" {
  description = "ARN of the remote QA CodeBuild project."
  value       = aws_codebuild_project.qa_remoto.arn
}

output "codebuild_service_role_arn" {
  description = "ARN of the CodeBuild service role."
  value       = aws_iam_role.codebuild.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for remote QA execution."
  value       = aws_cloudwatch_log_group.qa_remoto.name
}

output "monthly_budget_usd" {
  description = "Configured monthly budget in USD."
  value       = var.monthly_budget_usd
}

output "monthly_budget_name" {
  description = "Name of the AWS monthly budget."
  value       = aws_budgets_budget.qa_remoto.name
}
