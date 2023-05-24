#!/usr/local/bin/bash

. snapshot/check.sh
. snapshot/maven/assemble.sh

VARIANT='debug'

ISSUER="lib/build/maven/${VARIANT}/maven-metadata.xml"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
GROUP_ID="$(yq -p=xml -o=xml -e .metadata.groupId "$ISSUER")" || exit 1
ARTIFACT_ID="$(yq -p=xml -o=xml -e .metadata.artifactId "$ISSUER")" || exit 1
VERSION="$(yq -p=xml -o=xml -e .metadata.versioning.versions.version "$ISSUER")" || exit 1

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

ISSUER="lib/build/outputs/aar/${ARTIFACT_ID}-${VERSION}.aar"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

. util/sign/jar.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD" "$KEY_ALIAS"
. util/sign.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

ISSUER="lib/build/maven/${VARIANT}/maven-metadata.xml"
. util/sign.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

REPOSITORY_BASE='https://s01.oss.sonatype.org/content/repositories/snapshots'
REPOSITORY_GROUP="${REPOSITORY_BASE}/${GROUP_ID//.//}"
REMOTE="${REPOSITORY_GROUP}/${ARTIFACT_ID}"

curl -f "$REMOTE/" > /dev/null
if test $? -ne 0; then
 echo "Check repository \"$ARTIFACT_ID\" error!"; exit 1; fi

echo "Enter Maven snapshot username:"
read MAVEN_SNAPSHOT_USER

echo "Enter Maven snapshot password:"
read -rs MAVEN_SNAPSHOT_PASSWORD

for it in MAVEN_SNAPSHOT_USER MAVEN_SNAPSHOT_PASSWORD; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

ISSUER="lib/build/maven/${VARIANT}/maven-metadata.xml"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"

ISSUER="lib/build/outputs/aar/${ARTIFACT_ID}-${VERSION}.aar"
. util/sign/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD"
. util/sign/jar/check.sh "$ISSUER" "$KEYSTORE" "$KEYSTORE_PASSWORD" "$KEY_ALIAS"

PUBLIC_KEY="$(curl -f "$REPOSITORY_GROUP/debug-public.pem")"
if test $? -ne 0; then
 echo "Get public key \"$GROUP_ID\" error!"; exit 1; fi

ISSUER="lib/build/maven/${VARIANT}/maven-metadata.xml"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"
ISSUER="lib/build/outputs/aar/${ARTIFACT_ID}-${VERSION}.aar"
. util/sign/check/public.sh "$ISSUER" "$PUBLIC_KEY"

LOCAL="lib/build/libs"
for FILE in \
 "${ARTIFACT_ID}-${VERSION}-sources.jar"; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 curl -f -u "$MAVEN_SNAPSHOT_USER:$MAVEN_SNAPSHOT_PASSWORD" -T "$ISSUER" "$REMOTE/${VERSION}/$FILE"
 if test $? -ne 0; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

LOCAL="lib/build/outputs/aar"
for FILE in \
 "${ARTIFACT_ID}-${VERSION}.aar" \
 "${ARTIFACT_ID}-${VERSION}.aar.sig"; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 curl -f -u "$MAVEN_SNAPSHOT_USER:$MAVEN_SNAPSHOT_PASSWORD" -T "$ISSUER" "$REMOTE/${VERSION}/$FILE"
 if test $? -ne 0; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

LOCAL="lib/build/maven/${VARIANT}"
for FILE in \
 "${ARTIFACT_ID}-${VERSION}.pom"; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 curl -f -u "$MAVEN_SNAPSHOT_USER:$MAVEN_SNAPSHOT_PASSWORD" -T "$ISSUER" "$REMOTE/${VERSION}/$FILE"
 if test $? -ne 0; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

LOCAL="lib/build/maven/${VARIANT}"
for FILE in \
 "maven-metadata.xml" \
 "maven-metadata.xml.sig"; do
 ISSUER="$LOCAL/$FILE"
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
 curl -f -u "$MAVEN_SNAPSHOT_USER:$MAVEN_SNAPSHOT_PASSWORD" -T "$ISSUER" "$REMOTE/$FILE"
 if test $? -ne 0; then echo "Upload \"$ISSUER\" error!"; exit 1; fi
done

echo "$REMOTE/${VERSION}"
