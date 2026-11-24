data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_iam_role" "codebuild" {
  name = "spa-qa-remoto-codebuild-role"

  permissions_boundary = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/spa-qa-codebuild-boundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnEquals = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/spa-qa-remoto"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_logs" {
  name = "spa-qa-remoto-cloudwatch-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.qa_remoto.arn}:*"
      }
    ]
  })
}
