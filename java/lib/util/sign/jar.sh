#!/usr/local/bin/bash

if test $# -ne 4; then
 echo "Script needs 4 arguments: ISSUER, KEYSTORE, KEYSTORE_PASSWORD, KEY_ALIAS. But actual is $#!"; exit 1; fi

ISSUER="$1"
KEYSTORE="$2"
KEYSTORE_PASSWORD="$3"
KEY_ALIAS="$4"

for it in ISSUER KEYSTORE KEYSTORE_PASSWORD KEY_ALIAS; do
 if test -z "${!it}"; then echo "Argument \"$it\" is empty!"; exit 1; fi; done

if [[ ! -f "$KEYSTORE" ]]; then echo "File \"$KEYSTORE\" does not exist!"; exit 1; fi
if [[ ! -s "$KEYSTORE" ]]; then echo "File \"$KEYSTORE\" is empty!"; exit 1; fi

openssl pkcs12 -in "$KEYSTORE" -nokeys -passin "pass:$KEYSTORE_PASSWORD" | openssl x509 -checkend 0

if test $? -ne 0; then
 echo "Check \"$KEYSTORE\" error!"; exit 1; fi

if [[ ! -f "$ISSUER" ]]; then echo "File \"$ISSUER\" does not exist!"; exit 1; fi
if [[ ! -s "$ISSUER" ]]; then echo "File \"$ISSUER\" is empty!"; exit 1; fi

RESULT="$(jarsigner -verify "$ISSUER")"

if test $? -ne 0; then
 echo "Check signature of \"$ISSUER\" error!"; exit 1; fi

if test "${RESULT//$'\n'/}" != "jar is unsigned."; then
 echo "Jar \"$ISSUER\" already signed!"; exit 1; fi

jarsigner -keystore "$KEYSTORE" \
 -keypass "$KEYSTORE_PASSWORD" -storepass "$KEYSTORE_PASSWORD" \
 -sigalg SHA512withRSA -digestalg SHA-512 \
 "$ISSUER" "$KEY_ALIAS"

if test $? -ne 0; then
 echo "Sign jar \"$ISSUER\" error!"; exit 1; fi
