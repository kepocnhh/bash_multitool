#!/usr/local/bin/bash

BUILD_TYPE='debug'
FLAVOR='unstable'
VARIANT="${FLAVOR}${BUILD_TYPE^}"

gradle clean && \
 gradle "lib:assemble${VARIANT^}" && \
 gradle "lib:assemble${VARIANT^}Source" && \
 gradle "lib:assemble${VARIANT^}Pom"

if test $? -ne 0; then
 echo "Assemble \"$VARIANT\" error!"; exit 1; fi

ISSUER="lib/build/xml/${VARIANT}/maven.pom.xml"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
ARTIFACT_ID="$(yq -e .project.artifactId "$ISSUER")" || exit 1
VERSION="$(yq -e .project.version "$ISSUER")" || exit 1

for it in ARTIFACT_ID VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

mkdir -p "lib/build/maven/${VARIANT}"

cp "$ISSUER" "lib/build/maven/${VARIANT}/${ARTIFACT_ID}-${VERSION}.pom"

if test $? -ne 0; then
 echo "Copy \"${ISSUER}\" error!"; exit 1; fi

for ISSUER in \
 "lib/build/outputs/aar/${ARTIFACT_ID}-${VERSION}.aar" \
 "lib/build/sources/${VARIANT}/${ARTIFACT_ID}-${VERSION}-sources.jar" \
 "lib/build/maven/${VARIANT}/${ARTIFACT_ID}-${VERSION}.pom"; do
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
done
