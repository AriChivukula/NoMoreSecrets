set -e

wget https://releases.hashicorp.com/terraform/0.12.6/terraform_0.12.6_linux_amd64.zip
unzip terraform_0.12.6_linux_amd64.zip
rm terraform_0.12.6_linux_amd64.zip
./terraform init -backend-config="bucket=nomoresecrets" -backend-config="key=terraform.tfstate" .
