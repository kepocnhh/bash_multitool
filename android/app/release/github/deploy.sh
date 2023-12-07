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
VERSION="$(yq -erM .version "$ISSUER")" || exit 1

for it in REPOSITORY_OWNER REPOSITORY_NAME VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

URL="https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases/tags/${VERSION}"
CODE="$(curl -s -w '%{http_code}' -o /dev/null "$URL")"
if test $CODE -eq 200; then echo "Release \"$VERSION\" exists!"; exit 1
elif test $CODE -ne 404; then echo "Deploy \"$VERSION\" error!"; exit 1; fi

URL="https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/git/ref/tags/${VERSION}"
GITHUB_TAG="$(curl -f "$URL")"
if test $? -ne 0; then echo "Get tag \"$VERSION\" error!"; exit 1
elif test -z "$GITHUB_TAG"; then echo "Tag is empty!"; exit 1; fi

ACTUAL_SHA="$(echo "$GITHUB_TAG" | yq -erM .object.sha)" || exit 1
if test -z "$ACTUAL_SHA"; then echo "SHA is empty!"; exit 1
elif test "$ACTUAL_SHA" != "$SOURCE_SHA"; then
 echo "Expected SHA is $SOURCE_SHA, but actual is $ACTUAL_SHA!"; exit 1; fi

KEY_ALIAS="${BUILD_TYPE}"

for it in KEY_ALIAS; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

PUBLIC_KEY="$(curl -f "https://${REPOSITORY_OWNER}.github.io/${KEY_ALIAS}-public.pem")"
if test $? -ne 0; then
 echo "Get public key \"$REPOSITORY_OWNER\" error!"; exit 1; fi

. release/check.sh

echo "Enter keystore path:"
read -e KEYSTORE
KEYSTORE="$(echo "echo $KEYSTORE" | bash)"

echo "Enter keystore password:"
read -rs KEYSTORE_PASSWORD

for it in KEYSTORE KEYSTORE_PASSWORD; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

ISSUER="$KEYSTORE"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

gradle "app:assemble${VARIANT^}" -PSTORE_FILE="${KEYSTORE}" -PSTORE_PASSWORD="${KEYSTORE_PASSWORD}"

if test $? -ne 0; then
 echo "Assemble \"$VARIANT\" error!"; exit 1; fi

ISSUER="app/build/outputs/apk/${VARIANT}/${REPOSITORY_NAME}-${VERSION}.apk"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
. util/sign.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/apk/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"

ISSUER="app/build/outputs/mapping/${VARIANT}/mapping.txt"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
. util/sign.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"

echo "Enter VCS personal access token:"
read -rs VCS_PAT
if test -z "$VCS_PAT"; then echo "VCS personal access token is empty!"; exit 1; fi

MESSAGE="
- Download [apk](https://github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases/download/${VERSION}/${REPOSITORY_NAME}-${VERSION}.apk)
"
BODY="$(echo "{}" | yq -M -o=json ".name=\"$VERSION\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".tag_name=\"$VERSION\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".target_commitish=\"$SOURCE_SHA\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".body=\"$MESSAGE\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".draft=false")"
BODY="$(echo "$BODY" | yq -M -o=json ".prerelease=false")"

RELEASE="$(curl -f \
 -X POST "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases" \
 -H "Authorization: token $VCS_PAT" \
 -d "$BODY")"
if test $? -ne 0; then echo "Release \"$VERSION\" error!"; exit 1
elif test -z "$RELEASE"; then echo "Release is empty!"; exit 1; fi

UPLOAD_URL="$(echo "$RELEASE" | yq -erM .upload_url)" || exit 1
UPLOAD_URL="${UPLOAD_URL//\{?name,label\}/}"
for it in UPLOAD_URL; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

LOCAL="app/build/outputs/apk/${VARIANT}"
for FILE in \
 "${REPOSITORY_NAME}-${VERSION}.apk" \
 "${REPOSITORY_NAME}-${VERSION}.apk.sig"; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 CODE="$(curl -w '%{http_code}' -o /dev/null \
  -X POST "$UPLOAD_URL?name=$FILE" \
  -H "Authorization: token $VCS_PAT" \
  -H 'Content-Type: text/plain' \
  --data-binary "@$ISSUER")"
 if test $CODE -ne 201; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

LOCAL="app/build/outputs/mapping/${VARIANT}"
for FILE in \
 'mapping.txt' \
 'mapping.txt.sig'; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 CODE="$(curl -w '%{http_code}' -o /dev/null \
  -X POST "$UPLOAD_URL?name=$FILE" \
  -H "Authorization: token $VCS_PAT" \
  -H 'Content-Type: text/plain' \
  --data-binary "@$ISSUER")"
 if test $CODE -ne 201; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

echo "https://github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases/tag/${VERSION}"
