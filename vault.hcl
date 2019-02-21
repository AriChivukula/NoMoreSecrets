disable_mlock = true

listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = 1
}

seal "awskms" {
  kms_key_id = "d0381e19-1856-438c-9bf0-67ee67bc49e1"
}

storage "s3" {
  bucket = "nomoresecrets"
}

ui = true
