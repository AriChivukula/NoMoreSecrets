set -e

wget https://releases.hashicorp.com/terraform/0.11.11/terraform_0.11.11_linux_amd64.zip
unzip terraform_0.11.11_linux_amd64.zip
rm terraform_0.11.11_linux_amd64.zip
export TF_VAR_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID 
export TF_VAR_AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION 
export TF_VAR_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
./terraform init -backend-config="bucket=nomoresecrets" -backend-config="key=terraform.tfstate" .
./terraform plan .
