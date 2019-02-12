listener "tcp" {
  address = "127.0.0.1:80"
  tls_disable = 1
}

seal "awskms" {
  kms_key_id = "d0381e19-1856-438c-9bf0-67ee67bc49e1"
}

storage "s3" {
  bucket = "nomoresecrets"
}

ui = true
