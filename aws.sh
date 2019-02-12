set -e

sudo pip install awscli
eval $(aws ecr get-login --no-include-email)
