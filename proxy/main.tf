
terraform {
  cloud {
    organization = "hashi_strawb_testing"

    workspaces {
      name = "vault-plugin-wif-proxy"
    }
  }
}


variable "vault_addr" {
  default = "https://vault.lmhd.me"
}
variable "vault_namespace" {
  default = "demos/plugin-wif/"
}

locals {
  proxy_url = "${var.vault_addr}/v1/${var.vault_namespace}/identity/oidc/plugins"
}


# Using the examples from https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api

resource "aws_api_gateway_rest_api" "example" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "Plugin WIF Proxy"
      version = "1.0"
    }
    paths = {
      "${var.vault_namespace}/identity/oidc/plugins/.well-known/openid-configuration" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "${local.proxy_url}/.well-known/openid-configuration"
          }
        }
      }
      "${var.vault_namespace}/identity/oidc/plugins/.well-known/keys" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "${local.proxy_url}/.well-known/keys"
          }
        }
      }
    }
  })

  name = "Plugin WIF Proxy"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.example.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "v1"
}

output "invoke_url" {
  value = "${aws_api_gateway_stage.example.invoke_url}/${var.vault_namespace}identity/oidc/plugins/.well-known/openid-configuration"
}


# TODO: Custom Domain and ACM Cert
# https://github.com/hashicorp/terraform-provider-aws/blob/main/examples/api-gateway-rest-api-openapi/domain.tf
# https://github.com/hashicorp/terraform-provider-aws/blob/main/examples/api-gateway-rest-api-openapi/tls.tf
