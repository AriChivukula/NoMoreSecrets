set -e

docker build -t NoMoreSecrets:$TRAVIS_BRANCH .
docker tag NoMoreSecrets:$TRAVIS_BRANCH 617580300246.dkr.ecr.us-east-1.amazonaws.com/NoMoreSecrets:$TRAVIS_BRANCH
docker push 617580300246.dkr.ecr.us-east-1.amazonaws.com/NoMoreSecrets:$TRAVIS_BRANCH
