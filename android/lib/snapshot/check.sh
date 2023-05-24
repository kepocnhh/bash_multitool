#!/usr/local/bin/bash

VARIANT='debug'
TEST_VARIANT='debug'

gradle clean && \
 gradle "checkLicense" && \
 gradle "checkCodeStyle" && \
 gradle "lib:check${VARIANT^}Readme" && \
 gradle "lib:test${TEST_VARIANT^}UnitTest" && \
 gradle "lib:check${TEST_VARIANT^}Coverage" && \
 gradle "lib:check${VARIANT^}CodeQuality" && \
 gradle "lib:check${VARIANT^}CodeQualityUnitTest" && \
 gradle "lib:check${VARIANT^}Documentation"

if test $? -ne 0; then
 echo 'Check error!'; exit 1; fi
