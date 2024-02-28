#!/usr/local/bin/bash

VARIANT='snapshot'

gradle clean && \
 gradle 'checkLicense' && \
 gradle 'checkCodeStyle' && \
 gradle "lib:check${VARIANT^}Readme" && \
 gradle 'lib:checkUnitTest' && \
 gradle 'lib:checkCoverage' && \
 gradle 'lib:checkCodeQuality' && \
 gradle 'lib:checkCodeQualityTest' && \
 gradle 'lib:checkDocumentation' && \
 gradle "lib:assemble${VARIANT^}Metadata" && \
 gradle "lib:assemble${VARIANT^}MavenMetadata"

if test $? -ne 0; then
 echo 'Check error!'; exit 1; fi

ISSUER='lib/build/yml/metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
REPOSITORY_NAME="$(yq -erM .repository.name "$ISSUER")" || exit 1
VERSION="$(yq -erM .version "$ISSUER")" || exit 1

ISSUER='lib/build/yml/maven-metadata.yml'
if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi
ARTIFACT_ID="$(yq -e .repository.artifactId "$ISSUER")" || exit 1
MAVEN_VERSION="$(yq -e .version "$ISSUER")" || exit 1

if test "$REPOSITORY_NAME" != "$ARTIFACT_ID"; then
 echo "Repository name is \"$REPOSITORY_NAME\", but artifact ID is \"$ARTIFACT_ID\"!"; exit 1; fi

if test "$VERSION" != "$MAVEN_VERSION"; then
 echo "Repository version is \"$VERSION\", but maven version is \"$MAVEN_VERSION\"!"; exit 1; fi
