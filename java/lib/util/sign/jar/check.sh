#!/usr/local/bin/bash

if test $# -ne 4; then
 echo "Script needs 4 arguments: ISSUER, KEYSTORE, KEYSTORE_PASSWORD KEY_ALIAS. But actual is $#!"; exit 1; fi

KEYSTORE_TYPE='pkcs12'
ISSUER="$1"
KEYSTORE="$2"
KEYSTORE_PASSWORD="$3"
KEY_ALIAS="$4"

for it in ISSUER KEYSTORE KEYSTORE_PASSWORD KEYSTORE_TYPE KEY_ALIAS; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

if [[ ! -f "$KEYSTORE" ]]; then echo "File \"$KEYSTORE\" does not exist!"; exit 1
elif [[ ! -s "$KEYSTORE" ]]; then echo "File \"$KEYSTORE\" is empty!"; exit 1; fi

openssl "$KEYSTORE_TYPE" -in "$KEYSTORE" -nokeys -passin "pass:$KEYSTORE_PASSWORD" | openssl x509 -checkend 0

if test $? -ne 0; then
 echo "Check \"$KEYSTORE\" error!"; exit 1; fi

if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1
elif [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

jarsigner -verify "$ISSUER" &> /dev/null

if test $? -ne 0; then
 echo "Check signature of \"$ISSUER\" error!"; exit 1; fi

SIGNATURE="$(unzip -p "$ISSUER" "META-INF/${KEY_ALIAS^^}.SF")"
if test $? -ne 0; then
 echo "Get signature of \"$ISSUER\" error!"; exit 1; fi

SIGNER="$(openssl "$KEYSTORE_TYPE" -in "$KEYSTORE" -nokeys -nodes -passin "pass:${KEYSTORE_PASSWORD}")"
if test $? -ne 0; then
 echo "Get signer of \"$KEYSTORE\" error!"; exit 1; fi

KEY="$(openssl "$KEYSTORE_TYPE" -in "$KEYSTORE" -nocerts -nodes -passin "pass:${KEYSTORE_PASSWORD}")"
if test $? -ne 0; then
 echo "Get key of \"$KEYSTORE\" error!"; exit 1; fi

for it in SIGNATURE SIGNER KEY; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

openssl cms -verify -noverify -content <(echo "$SIGNATURE") -inform DER \
 -in <(openssl cms -sign -binary -noattr -outform DER \
  -signer <(echo "$SIGNER") -inkey <(echo "$KEY") -md sha256 -in <(echo "$SIGNATURE")) &> /dev/null
if test $? -ne 0; then
 echo "Check expected signature of \"$ISSUER\" error!"; exit 1; fi

openssl cms -verify -noverify -content <(echo "$SIGNATURE") -inform DER \
 -in <(unzip -p "$ISSUER" "META-INF/${KEY_ALIAS^^}.RSA") &> /dev/null
if test $? -ne 0; then
 echo "Check actual signature of \"$ISSUER\" error!"; exit 1; fi
