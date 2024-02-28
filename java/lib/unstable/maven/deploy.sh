#!/usr/local/bin/bash

. unstable/check.sh
. unstable/maven/assemble.sh
. unstable/maven/assemble/metadata.sh

ISSUER='lib/build/yml/maven-metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
GROUP_ID="$(yq -e .repository.groupId "$ISSUER")" || exit 1
ARTIFACT_ID="$(yq -e .repository.artifactId "$ISSUER")" || exit 1
VERSION="$(yq -e .version "$ISSUER")" || exit 1

for it in GROUP_ID ARTIFACT_ID VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

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

ISSUER='lib/build/xml/maven-metadata.xml'

if test "$(yq '.metadata.groupId' "$ISSUER")" != "$GROUP_ID"; then
 echo 'Wrong group ID!'; exit 1; fi
if test "$(yq '.metadata.artifactId' "$ISSUER")" != "$ARTIFACT_ID"; then
 echo 'Wrong artifact ID!'; exit 1; fi

MAVEN_VERSIONS_PATH='.metadata.versioning.versions.version'

RESULT="$(cat "$ISSUER" \
 | yq -p=xml -o=json "${MAVEN_VERSIONS_PATH} |= ([] + .)" \
 | yq -o=json "${MAVEN_VERSIONS_PATH}" \
 | yq "contains([\"$VERSION\"])")"

if test "$RESULT" != 'true'; then
 echo "Metadata has no version \"$VERSION\"!"; exit 1; fi

. util/sign.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

REPOSITORY_BASE='https://s01.oss.sonatype.org/content/repositories/snapshots'
REPOSITORY_GROUP="${REPOSITORY_BASE}/${GROUP_ID//.//}"
REMOTE="${REPOSITORY_GROUP}/${ARTIFACT_ID}"

curl -f "$REMOTE/" > /dev/null
if test $? -ne 0; then
 echo "Check repository \"${GROUP_ID}:${ARTIFACT_ID}\" error!"; exit 1; fi

echo "Enter Maven snapshot username:"
read MAVEN_SNAPSHOT_USER

echo "Enter Maven snapshot password:"
read -rs MAVEN_SNAPSHOT_PASSWORD

for it in MAVEN_SNAPSHOT_USER MAVEN_SNAPSHOT_PASSWORD; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

ISSUER='lib/build/xml/maven-metadata.xml'
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

ISSUER="lib/build/libs/${ARTIFACT_ID}-${VERSION}.jar"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/jar/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD" "$KEY_ALIAS"

PUBLIC_KEY="$(curl -f "$REPOSITORY_GROUP/debug-public.pem")"
if test $? -ne 0; then
 echo "Get public key \"$GROUP_ID\" error!"; exit 1; fi

ISSUER='lib/build/xml/maven-metadata.xml'
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"
ISSUER="lib/build/libs/${ARTIFACT_ID}-${VERSION}.jar"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"

LOCAL='lib/build/libs'
for it in '.jar' '.jar.sig' '-sources.jar' '.pom'; do
 FILE="${ARTIFACT_ID}-${VERSION}$it"
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 curl -f -u "$MAVEN_SNAPSHOT_USER:$MAVEN_SNAPSHOT_PASSWORD" -T "$ISSUER" "$REMOTE/${VERSION}/$FILE"
 if test $? -ne 0; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

LOCAL='lib/build/xml'
for it in '.xml' '.xml.sig'; do
 FILE="maven-metadata$it"
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 curl -f -u "$MAVEN_SNAPSHOT_USER:$MAVEN_SNAPSHOT_PASSWORD" -T "$ISSUER" "$REMOTE/$FILE"
 if test $? -ne 0; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

echo "$REMOTE/${VERSION}"
