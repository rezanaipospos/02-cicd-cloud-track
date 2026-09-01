# Read-only policy untuk backend-go mengakses KV secrets engine v2
path "secret/data/backend-go/*" {
  capabilities = ["read"]
}
path "secret/data/backend-go-cinema/*" {
  capabilities = ["read"]
}
path "secret/data/backend-go-payment/*" {
  capabilities = ["read"]
}
