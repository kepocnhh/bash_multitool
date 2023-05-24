#!/usr/local/bin/bash

if test $# -ne 3; then
 echo "Script needs 3 arguments: ISSUER, KEYSTORE, KEYSTORE_PASSWORD. But actual is $#!"; exit 1; fi

KEYSTORE_TYPE='pkcs12'
ISSUER="$1"
KEYSTORE="$2"
KEYSTORE_PASSWORD="$3"

for it in ISSUER KEYSTORE KEYSTORE_PASSWORD KEYSTORE_TYPE; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

if [[ ! -f "$KEYSTORE" ]]; then echo "File \"$KEYSTORE\" does not exist!"; exit 1
elif [[ ! -s "$KEYSTORE" ]]; then echo "File \"$KEYSTORE\" is empty!"; exit 1; fi

openssl "$KEYSTORE_TYPE" -in "$KEYSTORE" -nokeys -passin "pass:$KEYSTORE_PASSWORD" | openssl x509 -checkend 0

if test $? -ne 0; then
 echo "Check \"$KEYSTORE\" error!"; exit 1; fi

if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

if [[ ! -f "${ISSUER}.sig" ]]; then echo "File \"${ISSUER}.sig\" does not exist!"; exit 1
elif [[ ! -s "${ISSUER}.sig" ]]; then echo "File \"${ISSUER}.sig\" is empty!"; exit 1; fi

openssl dgst -sha512 -verify <(
  openssl "$KEYSTORE_TYPE" -in "$KEYSTORE" -nokeys -passin "pass:$KEYSTORE_PASSWORD" | openssl x509 -pubkey -noout
 ) -signature "${ISSUER}.sig" "$ISSUER"

if test $? -ne 0; then
 echo "Verify \"$ISSUER\" error!"; exit 1; fi
