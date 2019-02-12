set -e

wget https://releases.hashicorp.com/terraform/0.11.11/terraform_0.11.11_linux_amd64.zip
unzip terraform_0.11.11_linux_amd64.zip
rm terraform_0.11.11_linux_amd64.zip
./terraform init -backend-config="bucket=nomoresecrets" -backend-config="key=terraform.tfstate" terraform.hcl
./terraform plan terraform.hcl
