#!/usr/local/bin/bash

if test $# -ne 2; then
 echo "Script needs 2 arguments: ISSUER, KEY. But actual is $#!"; exit 1; fi

ISSUER="$1"
KEY="$2"

for it in ISSUER KEY; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

if [[ ! -f "${ISSUER}.sig" ]]; then echo "File \"${ISSUER}.sig\" does not exist!"; exit 1
elif [[ ! -s "${ISSUER}.sig" ]]; then echo "File \"${ISSUER}.sig\" is empty!"; exit 1; fi

openssl dgst -sha512 -verify <(echo "$KEY") -signature "${ISSUER}.sig" "$ISSUER"

if test $? -ne 0; then
 echo "Verify \"$ISSUER\" error!"; exit 1; fi
