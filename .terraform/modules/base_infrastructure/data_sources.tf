# selected subnets ids
data "aws_subnet_ids" "selected" {
  vpc_id = aws_vpc.main.id

  filter {
    name   = "tag:Name"
    values = [
      "*Public*"]
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = aws_vpc.main.id

  filter {
    name   = "tag:Name"
    values = [
      "*Private*"]
  }
}

data "aws_iam_policy_document" "ecs_tasks_execution_role" {
  version = "2008-10-17"
  statement {
    actions = [
      "sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"]
    }
  }
}

# ACM certificate for brain.gbuniversity.com
data "aws_acm_certificate" "brain-gbuniversity-com" {
  domain   = "*.brain-gbuniversity.com"
  statuses = [
    "ISSUED"]
}


/*#Policy for S3Bucket
data "aws_iam_policy_document" "S3Bucket-BasePolicy" {
  policy_id = "SSEAndSSLPolicy"
  version   = "2012-10-17"
  statement {
    sid = "DenyUnEncryptedObjectUploads"
    effect = "Deny"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.S3Bcuket_codepipeline}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values = [
        "aws:kms"
      ]
    }
  }

  statement {
    sid = "DenyInsecureConnections"
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${var.S3Bcuket_codepipeline}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }
}*/
