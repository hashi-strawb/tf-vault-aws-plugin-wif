terraform {
  cloud {
    organization = "hashi_strawb_testing"

    workspaces {
      name = "vault-aws-secrets-wif"
    }
  }
}

variable "oidc_audience" {
  default = "vault.lmhd.me:443/v1/identity/oidc/plugins"
}
variable "vault_plugins_addr" {
  default = "https://vault.lmhd.me/v1/identity/oidc/plugins"
}


# https://developer.hashicorp.com/vault/docs/secrets/aws#plugin-workload-identity-federation-wif
data "tls_certificate" "vault_certificate" {
  url = var.vault_plugins_addr
}
resource "aws_iam_openid_connect_provider" "vault_provider" {
  url             = data.tls_certificate.vault_certificate.url
  client_id_list  = [var.oidc_audience]
  thumbprint_list = [data.tls_certificate.vault_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "plugins_role" {
  name = "vault-lmhd-me-oidc-plugins"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "${aws_iam_openid_connect_provider.vault_provider.arn}"
     },
     "Action": "sts:AssumeRoleWithWebIdentity"
   }
 ]
}
EOF

  # TODO: this is waaaaay too much access; limit it to just what's needed
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "vault_aws_secret_backend" "aws" {
  path                    = "aws/lmhd/test-oidc"
  identity_token_audience = var.oidc_audience
  role_arn                = aws_iam_role.plugins_role.arn
}

resource "vault_aws_secret_backend_role" "test" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "test"
  credential_type = "iam_user"

  policy_document = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOT
}
