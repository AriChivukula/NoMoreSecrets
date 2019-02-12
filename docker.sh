set -e

sudo pip install awscli
eval $(aws ecr get-login --no-include-email)
docker build -t nomoresecrets:$TRAVIS_BRANCH .
docker tag nomoresecrets:$TRAVIS_BRANCH 617580300246.dkr.ecr.us-east-1.amazonaws.com/nomoresecrets:$TRAVIS_BRANCH
docker push 617580300246.dkr.ecr.us-east-1.amazonaws.com/nomoresecrets:$TRAVIS_BRANCH
