# API Proxy for the Vault Plugin WIF

Per https://developer.hashicorp.com/vault/docs/secrets/aws#plugin-workload-identity-federation-wif
you can create a proxy to the `identity/oidc/plugins` URLs, so as not to expose your entire Vault to the internet.

The TF config in here is an example of that.
