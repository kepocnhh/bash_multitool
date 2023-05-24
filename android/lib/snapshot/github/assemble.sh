#!/usr/local/bin/bash

VARIANT='debug'

gradle clean && \
 gradle "lib:assemble${VARIANT^}Metadata" && \
 gradle "lib:assemble${VARIANT^}MavenMetadata" && \
 gradle "lib:assemble${VARIANT^}"

if test $? -ne 0; then
 echo "Assemble \"$VARIANT\" error!"; exit 1; fi

ISSUER="lib/build/maven/${VARIANT}/maven-metadata.xml"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

ISSUER="lib/build/yml/${VARIANT}/metadata.yml"
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
REPOSITORY_NAME="$(yq -e .repository.name "$ISSUER")" || exit 1
VERSION="$(yq -e .version "$ISSUER")" || exit 1

for it in REPOSITORY_NAME VERSION; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

for ISSUER in \
 "lib/build/outputs/aar/${REPOSITORY_NAME}-${VERSION}.aar"; do
 if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
 elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
done
