set -e

mkdir -p $GOPATH/src/github.com/hashicorp
cd $GOPATH/src/github.com/hashicorp
git clone https://github.com/hashicorp/vault.git
cd vault
make bootstrap
make dev
make test
make bin
