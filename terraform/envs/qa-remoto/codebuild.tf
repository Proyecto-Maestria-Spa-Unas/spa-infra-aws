locals {
  qa_buildspec_dir = "${path.module}/../../../buildspecs"

  qa_buildspec = replace(
    replace(
      replace(
        replace(
          file("${local.qa_buildspec_dir}/buildspec.yml"),
          "$${humo_b64}",
          filebase64("${local.qa_buildspec_dir}/humo.sh")
        ),
        "$${backend_b64}",
        filebase64("${local.qa_buildspec_dir}/backend.sh")
      ),
      "$${database_b64}",
      filebase64("${local.qa_buildspec_dir}/database.sh")
    ),
    "$${frontend_b64}",
    filebase64("${local.qa_buildspec_dir}/frontend.sh")
  )
}

resource "aws_codebuild_project" "qa_remoto" {
  name                   = "spa-qa-remoto"
  description            = "Remote QA testing environment for SPA UNAS"
  service_role           = aws_iam_role.codebuild.arn
  build_timeout          = var.build_timeout_minutes
  queued_timeout         = 15
  concurrent_build_limit = 1

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "REPO"
      value = "spa-backend-api"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "REF"
      value = "develop"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "SUITE"
      value = "humo"
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = local.qa_buildspec
  }

  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = aws_cloudwatch_log_group.qa_remoto.name
      stream_name = "qa"
    }

    s3_logs {
      status = "DISABLED"
    }
  }

  depends_on = [
    aws_iam_role_policy.codebuild_logs
  ]

  tags = {
    Name = "spa-qa-remoto"
  }
}
