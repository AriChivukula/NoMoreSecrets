set -e

wget https://releases.hashicorp.com/terraform/0.12.0/terraform_0.12.0_linux_amd64.zip
unzip terraform_0.12.0_linux_amd64.zip
rm terraform_0.12.0_linux_amd64.zip
./terraform init -backend-config="bucket=nomoresecrets" -backend-config="key=terraform.tfstate" .
./terraform plan .
