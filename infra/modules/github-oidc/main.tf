locals {
  issuer            = "token.actions.githubusercontent.com"
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.oidc_provider_arn

  sub_pull_request = "repo:${var.github_repository}:pull_request"
  sub_apply_branch = "repo:${var.github_repository}:ref:refs/heads/${var.apply_branch}"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.issuer}"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

data "aws_iam_policy_document" "trust" {
  for_each = {
    tofu_plan  = [local.sub_pull_request]
    tofu_apply = [local.sub_apply_branch]
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:sub"
      values   = each.value
    }
  }
}

resource "aws_iam_role" "tofu_plan" {
  name               = "${var.name_prefix}-gha-tofu-plan"
  assume_role_policy = data.aws_iam_policy_document.trust["tofu_plan"].json
  tags               = var.tags
}

resource "aws_iam_role" "tofu_apply" {
  name               = "${var.name_prefix}-gha-tofu-apply"
  assume_role_policy = data.aws_iam_policy_document.trust["tofu_apply"].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "tofu_plan_read_only" {
  role       = aws_iam_role.tofu_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "tofu_apply" {
  statement {
    sid       = "Infrastructure"
    actions   = ["ec2:*", "eks:*"]
    resources = ["*"]
  }

  statement {
    sid = "ProjectRoles"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = ["arn:aws:iam::*:role/${var.name_prefix}-*"]
  }

  statement {
    sid       = "IamRead"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "tofu_apply" {
  name   = "tofu-apply"
  role   = aws_iam_role.tofu_apply.id
  policy = data.aws_iam_policy_document.tofu_apply.json
}
