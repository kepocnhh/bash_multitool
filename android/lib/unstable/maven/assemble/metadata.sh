#!/usr/local/bin/bash

FLAVOR='unstable'
BUILD_TYPE='debug'
VARIANT="${FLAVOR}${BUILD_TYPE^}"

ISSUER="lib/build/xml/${VARIANT}/maven.pom.xml"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
GROUP_ID="$(yq -e .project.groupId "$ISSUER")" || exit 1
ARTIFACT_ID="$(yq -e .project.artifactId "$ISSUER")" || exit 1
VERSION="$(yq -e .project.version "$ISSUER")" || exit 1

for it in GROUP_ID ARTIFACT_ID VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

REPOSITORY_BASE='https://s01.oss.sonatype.org/content/repositories/snapshots'
REPOSITORY_GROUP="${REPOSITORY_BASE}/${GROUP_ID//.//}"
REMOTE="${REPOSITORY_GROUP}/${ARTIFACT_ID}"

MAVEN_METADATA_REMOTE="$(curl -f "$REMOTE/maven-metadata.xml")"
if test $? -ne 0; then
 echo "Metadata of \"${GROUP_ID}:${ARTIFACT_ID}\" does not exist!"; exit 1; fi
if test -z "$MAVEN_METADATA_REMOTE"; then
 echo "Metadata of \"${GROUP_ID}:${ARTIFACT_ID}\" is empty!"; exit 1; fi

MAVEN_VERSIONS_PATH='.metadata.versioning.versions.version'

ISSUER="lib/build/maven/${VARIANT}/maven-metadata.xml"

echo "$MAVEN_METADATA_REMOTE" \
 | yq -p=xml -o=json "${MAVEN_VERSIONS_PATH} |= ([] + .)" \
 | yq -o=json "${MAVEN_VERSIONS_PATH} += \"$VERSION\"" \
 | yq -p=json -o=xml ".metadata.versioning.lastUpdated = \"$(date -u +%Y%m%d%H%M%S)\"" \
 > "$ISSUER"

if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

if test "$(yq '.metadata.groupId' "$ISSUER")" != "$GROUP_ID"; then
 echo 'Wrong group ID!'; exit 1; fi
if test "$(yq '.metadata.artifactId' "$ISSUER")" != "$ARTIFACT_ID"; then
 echo 'Wrong artifact ID!'; exit 1; fi

RESULT="$(cat "$ISSUER" \
 | yq -p=xml -o=json "${MAVEN_VERSIONS_PATH} |= ([] + .)" \
 | yq -o=json "${MAVEN_VERSIONS_PATH}" \
 | yq "contains([\"$VERSION\"])")"

if test "$RESULT" != 'true'; then
 echo "Metadata has no version \"$VERSION\"!"; exit 1; fi
