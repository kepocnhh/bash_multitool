#!/usr/local/bin/bash

VARIANT='unstable'

gradle clean && \
 gradle 'checkLicense' && \
 gradle 'checkCodeStyle' && \
 gradle "lib:check${VARIANT^}Readme"

if test $? -ne 0; then
 echo 'Check error!'; exit 1; fi
