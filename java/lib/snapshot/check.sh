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
 gradle 'lib:checkDocumentation'

if test $? -ne 0; then
 echo 'Check error!'; exit 1; fi
