#!/usr/local/bin/bash

VARIANT='snapshot'

gradle clean && \
 gradle "lib:assemble${VARIANT^}Metadata" && \
 gradle "lib:assemble${VARIANT^}MavenMetadata" && \
 gradle "lib:assemble${VARIANT^}Jar"

if test $? -ne 0; then
 echo "Assemble \"$VARIANT\" error!"; exit 1; fi

ISSUER='lib/build/yml/maven-metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
ARTIFACT_ID="$(yq -e .repository.artifactId "$ISSUER")" || exit 1
VERSION="$(yq -e .version "$ISSUER")" || exit 1

ISSUER='lib/build/yml/metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

for it in ARTIFACT_ID VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

for ISSUER in \
 "lib/build/libs/${ARTIFACT_ID}-${VERSION}.jar"; do
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
done
