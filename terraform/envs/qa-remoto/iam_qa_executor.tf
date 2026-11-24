locals {
  qa_log_group_arn = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.qa_remoto.name}"
}

resource "aws_iam_policy" "qa_executor" {
  name        = "spa-qa-ejecutor"
  description = "Restricted remote QA execution policy for SPA UNAS"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        Action = [
          "codebuild:*",
          "logs:*"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "AllowRestrictedStartBuild"
        Effect = "Allow"
        Action = "codebuild:StartBuild"

        Resource = aws_codebuild_project.qa_remoto.arn

        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }

          BoolIfExists = {
            "codebuild:source.buildspec"               = "false"
            "codebuild:secondarySources"               = "false"
            "codebuild:secondaryArtifacts"             = "false"
            "codebuild:artifacts"                      = "false"
            "codebuild:cache"                          = "false"
            "codebuild:logsConfig"                     = "false"
            "codebuild:environment.registryCredential" = "false"
            "codebuild:environment.privilegedMode"     = "true"
          }

          "ForAllValues:StringEquals" = {
            "codebuild:environment.environmentVariables.name" = [
              "REPO",
              "REF",
              "SUITE"
            ]
          }

          StringEquals = {
            "codebuild:environment.environmentVariables/REPO.value" = [
              "spa-backend-api",
              "spa-frontend-web",
              "spa-database"
            ]

            "codebuild:environment.environmentVariables/SUITE.value" = [
              "unitarias",
              "integracion",
              "todo"
            ]
          }

          StringEqualsIfExists = {
            "codebuild:environment.computeType"              = "BUILD_GENERAL1_SMALL"
            "codebuild:environment.image"                    = "aws/codebuild/standard:7.0"
            "codebuild:environment.type"                     = "LINUX_CONTAINER"
            "codebuild:environment.imagePullCredentialsType" = "CODEBUILD"
            "codebuild:serviceRole"                          = aws_iam_role.codebuild.arn
          }

          NumericEqualsIfExists = {
            "codebuild:autoRetryLimit" = "0"
          }

          Null = {
            "codebuild:environment.environmentVariables.name"      = "false"
            "codebuild:environment.environmentVariables/REF.value" = "false"
            "codebuild:environment.fleet.fleetArn"                 = "true"
            "codebuild:source.location"                            = "true"
            "codebuild:source.auth.resource"                       = "true"
            "codebuild:source.auth.type"                           = "true"
            "codebuild:environment.certificate"                    = "true"
            "codebuild:encryptionKey"                              = "true"
          }
        }
      },
      {
        Sid    = "AllowBuildStatusAndStop"
        Effect = "Allow"

        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StopBuild"
        ]

        Resource = aws_codebuild_project.qa_remoto.arn

        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      },
      {
        Sid      = "AllowFilterQALogs"
        Effect   = "Allow"
        Action   = "logs:FilterLogEvents"
        Resource = local.qa_log_group_arn

        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      },
      {
        Sid      = "AllowReadQALogStreams"
        Effect   = "Allow"
        Action   = "logs:GetLogEvents"
        Resource = "${local.qa_log_group_arn}:log-stream:*"

        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name = "spa-qa-ejecutor"
  }
}
