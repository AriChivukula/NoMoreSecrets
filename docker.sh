set -e

docker build -t nomoresecrets:$TRAVIS_BRANCH .
docker tag nomoresecrets:$TRAVIS_BRANCH 617580300246.dkr.$AWS_DEFAULT_REGION.amazonaws.com/nomoresecrets:$TRAVIS_BRANCH
docker push 617580300246.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/nomoresecrets:$TRAVIS_BRANCH
