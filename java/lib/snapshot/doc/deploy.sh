#!/usr/local/bin/bash

VARIANT='snapshot'

gradle clean && \
 gradle "lib:assemble${VARIANT^}Metadata" && \
 gradle "lib:assemble${VARIANT^}Documentation"

if test $? -ne 0; then
 echo "Assemble \"$VARIANT\" error!"; exit 1; fi

ISSUER='lib/build/yml/metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
REPOSITORY_OWNER="$(yq -erM .repository.owner "$ISSUER")" || exit 1
REPOSITORY_NAME="$(yq -erM .repository.name "$ISSUER")" || exit 1
VERSION="$(yq -erM .version "$ISSUER")" || exit 1

ISSUER="lib/build/documentation/${VARIANT}/index.html"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

IMAGE='kepocnhh/gradle-arm64v8:7.6.1'
CONTAINER="doc.${VARIANT}.container"

for it in REPOSITORY_OWNER REPOSITORY_NAME; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

docker stop "$CONTAINER"
docker rm "$CONTAINER"

echo 'Enter VCS token:'
read -rs VCS_PAT

docker run -id --name "$CONTAINER" "$IMAGE"

if test $? -ne 0; then
 echo 'Run error!'; exit 1; fi

GITHUB_USER="$(curl -f 'https://api.github.com/user' -H "Authorization: token $VCS_PAT")"
if test $? -ne 0; then echo 'Get user error!'; exit 1
elif test -z "$GITHUB_USER"; then echo 'User is empty!'; exit 1; fi

USER_NAME="$(echo "$GITHUB_USER" | yq -erM .name)" || exit 1
USER_ID="$(echo "$GITHUB_USER" | yq -erM .id)" || exit 1
USER_LOGIN="$(echo "$GITHUB_USER" | yq -erM .login)" || exit 1
USER_EMAIL="${USER_ID}+${USER_LOGIN}@users.noreply.github.com"

for it in USER_NAME USER_EMAIL; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

docker exec "$CONTAINER" mkdir -p "/$REPOSITORY_OWNER/$REPOSITORY_NAME/doc"

if test $? -ne 0; then
 echo 'Make dir error!'; exit 1; fi

for it in \
 'git init' \
 "git remote add origin https://${VCS_PAT}@github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}.git" \
 'git fetch --depth=1 origin gh-pages' \
 'git checkout gh-pages'; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo 'Checkout error!'; exit 1; fi
done

docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" \
 bash -c "[[ ! -s doc/$VERSION/index.html ]]"

if test $? -ne 0; then
 echo "Documentation \"$VERSION\" exists!"; exit 1; fi

for it in \
 "git config user.name '$USER_NAME'" \
 "git config user.email '$USER_EMAIL'"; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Config error!"; exit 1; fi
done

docker cp "lib/build/documentation/$VARIANT" "$CONTAINER:/$REPOSITORY_OWNER/$REPOSITORY_NAME/doc/$VERSION"

if test $? -ne 0; then
 echo 'Copy error!'; exit 1; fi

for it in \
 'git add --all .' \
 "git commit -m 'doc/$VERSION'" \
 "git tag 'doc/$VERSION'" \
 'git push' \
 'git push --tag'; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Push error!"; exit 1; fi
done

docker stop "$CONTAINER"
docker rm "$CONTAINER"

echo "https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME}/doc/${VERSION}"
