#!/usr/local/bin/bash

BUILD_TYPE='release'
FLAVOR_NAME=''

if test -z "$FLAVOR_NAME"; then
 VARIANT="${BUILD_TYPE}"
else
 VARIANT="${FLAVOR_NAME}${BUILD_TYPE^}"
fi

TEST_BUILD_TYPE='examine'

if test -z "$FLAVOR_NAME"; then
 TEST_VARIANT="${TEST_BUILD_TYPE}"
else
 TEST_VARIANT="${FLAVOR_NAME}${TEST_BUILD_TYPE^}"
fi

gradle clean && \
 gradle 'checkLicense' && \
 gradle "app:check${VARIANT^}Readme" && \
 gradle "app:check${VARIANT^}CodeStyle" && \
 gradle "app:test${TEST_VARIANT^}UnitTest" && \
 gradle "app:check${TEST_VARIANT^}Coverage" && \
 gradle "app:check${VARIANT^}CodeQuality" && \
 gradle "app:check${TEST_VARIANT^}CodeQualityUnitTest"

if test $? -ne 0; then
 echo 'Check error!'; exit 1; fi
