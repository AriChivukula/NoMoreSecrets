set -e

wget https://releases.hashicorp.com/terraform/0.12.1/terraform_0.12.1_linux_amd64.zip
unzip terraform_0.12.1_linux_amd64.zip
rm terraform_0.12.1_linux_amd64.zip
./terraform init -backend-config="bucket=nomoresecrets" -backend-config="key=terraform.tfstate" .
./terraform plan .
