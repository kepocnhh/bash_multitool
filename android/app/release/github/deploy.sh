#!/usr/local/bin/bash

. release/check.sh

BUILD_TYPE='release'
FLAVOR_NAME=''

gradle clean

if test $? -ne 0; then
 echo "Gradle error!"; exit 1; fi

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

echo "Enter keystore path:"
read -e KEYSTORE
KEYSTORE="$(echo "echo $KEYSTORE" | bash)"

echo "Enter keystore password:"
read -rs KEYSTORE_PASSWORD

KEY_ALIAS="${BUILD_TYPE}"

for it in KEYSTORE KEYSTORE_PASSWORD KEY_ALIAS; do
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

URL="https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases/tags/${VERSION}"
CODE="$(curl -s -w '%{http_code}' -o /dev/null "$URL")"
if test $CODE -eq 200; then echo "Release \"$VERSION\" exists!"; exit 1
elif test $CODE -ne 404; then echo "Deploy \"$VERSION\" error!"; exit 1; fi

ISSUER="app/build/outputs/apk/${VARIANT}/${REPOSITORY_NAME}-${VERSION}.apk"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

PUBLIC_KEY="$(curl -f "https://${REPOSITORY_OWNER}.github.io/${KEY_ALIAS}-public.pem")"
if test $? -ne 0; then
 echo "Get public key \"$REPOSITORY_OWNER\" error!"; exit 1; fi

ISSUER="app/build/outputs/apk/${VARIANT}/${REPOSITORY_NAME}-${VERSION}.apk"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"

VERSION='0.0.1-1-UNSTABLE' # todo
TAG="$(curl -f "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/git/refs/tags/${VERSION}")"
if test $? -ne 0; then echo "Get tag \"$VERSION\" error!"; exit 1
elif test -z "$TAG"; then echo "Tag is empty!"; exit 1; fi

SHA="$(echo "$TAG" | yq -erM .object.sha)" || exit 1
if test -z "$SHA"; then echo "Sha is empty!"; exit 1; fi

echo 'Not implemented!'; exit 1

echo "Enter VCS personal access token:"
read -rs VCS_PAT
if test -z "$VCS_PAT"; then echo "VCS personal access token is empty!"; exit 1; fi

MESSAGE="
- [Maven](https://s01.oss.sonatype.org/content/repositories/snapshots/${GROUP_ID//.//}/${ARTIFACT_ID}/${VERSION})
- [Documentation](https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME}/doc/${VERSION})
"
BODY="$(echo "{}" | yq -M -o=json ".name=\"$VERSION\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".tag_name=\"$VERSION\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".target_commitish=\"$SHA\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".body=\"$MESSAGE\"")"
BODY="$(echo "$BODY" | yq -M -o=json ".draft=false")"
BODY="$(echo "$BODY" | yq -M -o=json ".prerelease=true")"
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

LOCAL='lib/build/outputs/aar'
for FILE in \
 "${REPOSITORY_NAME}-${VERSION}.aar" \
 "${REPOSITORY_NAME}-${VERSION}.aar.sig"; do
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
