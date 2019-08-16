set -e

sudo pip install awscli
eval $(aws ecr get-login --no-include-email)
sudo update-ca-certificates
cp /etc/ssl/certs/ca-certificates.crt .
docker build -f docker.file -t nomoresecrets:master .
docker tag nomoresecrets:$TRAVIS_BRANCH 617580300246.dkr.ecr.us-east-1.amazonaws.com/nomoresecrets:master
