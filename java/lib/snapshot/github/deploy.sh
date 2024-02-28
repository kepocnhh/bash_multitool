#!/usr/local/bin/bash

. snapshot/check.sh
. snapshot/github/assemble.sh
. snapshot/maven/assemble/metadata.sh

ISSUER='lib/build/yml/metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
REPOSITORY_OWNER="$(yq -erM .repository.owner "$ISSUER")" || exit 1
REPOSITORY_NAME="$(yq -erM .repository.name "$ISSUER")" || exit 1
VERSION="$(yq -erM .version "$ISSUER")" || exit 1

for it in REPOSITORY_OWNER REPOSITORY_NAME VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

ISSUER='lib/build/yml/maven-metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
GROUP_ID="$(yq -e .repository.groupId "$ISSUER")" || exit 1
ARTIFACT_ID="$(yq -e .repository.artifactId "$ISSUER")" || exit 1

for it in GROUP_ID ARTIFACT_ID; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

if test "$VERSION" != "$(yq -e .version "$ISSUER")"; then
 echo "Version error!"; exit 1; fi

echo "Enter keystore path:"
read -e KEYSTORE
KEYSTORE="$(echo "echo $KEYSTORE" | bash)"

echo "Enter keystore password:"
read -rs KEYSTORE_PASSWORD

echo "Enter key alias:"
read KEY_ALIAS

for it in KEYSTORE KEYSTORE_PASSWORD KEY_ALIAS; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

ISSUER="$KEYSTORE"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

ISSUER="lib/build/libs/${ARTIFACT_ID}-${VERSION}.jar"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

. util/sign/jar.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD" "$KEY_ALIAS"
. util/sign.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

URL="https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases/tags/${VERSION}"
CODE="$(curl -s -w %{http_code} -o /dev/null "$URL")"
if test $CODE -eq 200; then echo "Release \"$VERSION\" exists!"; exit 1
elif test $CODE -ne 404; then echo "Deploy \"$VERSION\" error!"; exit 1; fi

TAG="$(curl -f "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/git/refs/tags/${VERSION}")"
if test $? -ne 0; then echo "Get tag \"$?\" error $CODE!"; exit 1
elif test -z "$TAG"; then echo "Tag is empty!"; exit 1; fi

SHA="$(echo "$TAG" | yq -erM .object.sha)" || exit 1
if test -z "$SHA"; then echo "Sha is empty!"; exit 1; fi

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

ISSUER="lib/build/libs/${ARTIFACT_ID}-${VERSION}.jar"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/jar/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD" "$KEY_ALIAS"

PUBLIC_KEY="$(curl -f "https://${REPOSITORY_OWNER}.github.io/debug-public.pem")"
if test $? -ne 0; then
 echo "Get public key \"$REPOSITORY_OWNER\" error!"; exit 1; fi

ISSUER="lib/build/libs/${ARTIFACT_ID}-${VERSION}.jar"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"

LOCAL='lib/build/libs'
for FILE in \
 "${ARTIFACT_ID}-${VERSION}.jar" \
 "${ARTIFACT_ID}-${VERSION}.jar.sig"; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 CODE="$(curl -w %{http_code} -o /dev/null \
  -X POST "$UPLOAD_URL?name=$FILE" \
  -H "Authorization: token $VCS_PAT" \
  -H 'Content-Type: text/plain' \
  --data-binary "@$ISSUER")"
 if test $CODE -ne 201; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

echo "https://github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/releases/tag/${VERSION}"
