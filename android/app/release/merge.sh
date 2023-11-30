#!/usr/local/bin/bash

git diff-index --quiet HEAD && \
 [[ -z "$(git status --porcelain)" ]]

if test $? -ne 0; then
 echo "The repository has changes!"; exit 1; fi

SOURCE_SHA="$(git rev-parse HEAD)"

for it in SOURCE_SHA; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

gradle clean

if test $? -ne 0; then
 echo "Gradle error!"; exit 1; fi

BUILD_TYPE='release'
FLAVOR_NAME=''

if test -z "$FLAVOR_NAME"; then
 VARIANT="${BUILD_TYPE}"
else
 VARIANT="${FLAVOR_NAME}${BUILD_TYPE^}"
fi

gradle "app:assemble${VARIANT^}Metadata"

if test $? -ne 0; then
 echo "Assemble \"$VARIANT\" metadata error!"; exit 1; fi

ISSUER="app/build/yml/${VARIANT}/metadata.yml"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
REPOSITORY_OWNER="$(yq -erM .repository.owner "$ISSUER")" || exit 1
REPOSITORY_NAME="$(yq -erM .repository.name "$ISSUER")" || exit 1

for it in REPOSITORY_OWNER REPOSITORY_NAME; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

echo "Enter VCS token:"
read -rs VCS_PAT

GITHUB_USER="$(curl -f 'https://api.github.com/user' -H "Authorization: token $VCS_PAT")"
if test $? -ne 0; then echo "Get user error!"; exit 1
elif test -z "$GITHUB_USER"; then echo "User is empty!"; exit 1; fi

USER_NAME="$(echo "$GITHUB_USER" | yq -erM .name)" || exit 1
USER_ID="$(echo "$GITHUB_USER" | yq -erM .id)" || exit 1
USER_LOGIN="$(echo "$GITHUB_USER" | yq -erM .login)" || exit 1
USER_EMAIL="${USER_ID}+${USER_LOGIN}@users.noreply.github.com"

for it in USER_NAME USER_EMAIL; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

GITHUB_COMMIT="$(curl -f "https://api.github.com/repos/$REPOSITORY_OWNER/$REPOSITORY_NAME/commits/$SOURCE_SHA")"
if test $? -ne 0; then echo "Get commit \"$SOURCE_SHA\" error!"; exit 1
elif test -z "$GITHUB_COMMIT"; then echo "The commit \"$SOURCE_SHA\" is empty!"; exit 1; fi

IMAGE='kepocnhh/android-amd64:5'
CONTAINER="release.merge.container"

docker stop "$CONTAINER"
docker rm "$CONTAINER"

docker run --platform='linux/amd64' -id --name "$CONTAINER" "$IMAGE"

if test $? -ne 0; then
 echo "Run error!"; exit 1; fi

docker exec "$CONTAINER" mkdir -p "/$REPOSITORY_OWNER/$REPOSITORY_NAME"

if test $? -ne 0; then
 echo "Make dir error!"; exit 1; fi

TARGET_BRANCH='master'

for it in \
 'git init' \
 "git remote add origin https://${VCS_PAT}@github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}.git" \
 "git fetch origin ${TARGET_BRANCH}" \
 "git checkout ${TARGET_BRANCH}"; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Checkout error!"; exit 1; fi
done

for it in \
 "git config user.name '$USER_NAME'" \
 "git config user.email '$USER_EMAIL'"; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Config error!"; exit 1; fi
done

for it in \
 "git fetch origin ${SOURCE_SHA}" \
 "git merge --no-ff --no-commit ${SOURCE_SHA}"; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Merge error!"; exit 1; fi
done

docker cp 'release/check.sh' "$CONTAINER:/$REPOSITORY_OWNER/$REPOSITORY_NAME/check.sh"

if test $? -ne 0; then
 echo "Copy error!"; exit 1; fi

for it in \
 './check.sh'; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Check error!"; exit 1; fi
done

ISSUER="app/build/yml/${VARIANT}/metadata.yml"
for it in \
 "gradle app:assemble${VARIANT^}Metadata" \
 "[[ -f '$ISSUER' ]] && [[ -s '$ISSUER' ]]" \
 "yq -erM .version '$ISSUER'" \
 "[[ -n \"\$(yq -erM .version '$ISSUER')\" ]]" \
 "git commit -m \"$TARGET_BRANCH <- \$(yq -erM .version '$ISSUER')\"" \
 "git tag \"\$(yq -erM .version '$ISSUER')\""; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Commit error!"; exit 1; fi
done

for it in \
 'git push' \
 'git push --tag'; do
 docker exec -w "/$REPOSITORY_OWNER/$REPOSITORY_NAME" "$CONTAINER" bash -c "$it"
 if test $? -ne 0; then echo "Push error!"; exit 1; fi
done

docker stop "$CONTAINER"
docker rm "$CONTAINER"

git fetch -p
git checkout "${TARGET_BRANCH}"
git pull

echo "https://github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/tree/${TARGET_BRANCH}"
