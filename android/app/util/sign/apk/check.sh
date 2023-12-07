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

APK_CERTS="$(apksigner verify --print-certs "$ISSUER")"
if test $? -ne 0; then
 echo "Check signature of \"$ISSUER\" by \"apksigner\" error!"; exit 1; fi

ACTUAL_CERT_SHA256="$(echo "$APK_CERTS" | grep 'Signer #1 certificate SHA-256 digest: ')"
if test $? -ne 0; then
 echo "Check SHA256 cert of \"$ISSUER\" error!"; exit 1; fi
ACTUAL_CERT_SHA256="${ACTUAL_CERT_SHA256//Signer #1 certificate SHA-256 digest: /}"
ACTUAL_CERT_SHA256="${ACTUAL_CERT_SHA256^^}"
if test ${#ACTUAL_CERT_SHA256} -ne 64; then
 echo "Check SHA256 cert of \"$ISSUER\" error! Wrong length."; exit 1; fi

SIGNER="$(openssl "$KEYSTORE_TYPE" -in "$KEYSTORE" -nokeys -nodes -passin "pass:${KEYSTORE_PASSWORD}")"
if test $? -ne 0; then
 echo "Get signer of \"$KEYSTORE\" error!"; exit 1; fi

EXPECTED_CERT_SHA256="$(openssl x509 -noout -fingerprint -sha256 -inform pem -in <(echo "$SIGNER"))"
if test $? -ne 0; then
 echo "Get expected SHA256 cert error!"; exit 1; fi
EXPECTED_CERT_SHA256="${EXPECTED_CERT_SHA256//SHA256 Fingerprint=/}"
EXPECTED_CERT_SHA256="${EXPECTED_CERT_SHA256//:/}"
EXPECTED_CERT_SHA256="${EXPECTED_CERT_SHA256^^}"
if test ${#EXPECTED_CERT_SHA256} -ne 64; then
 echo "Get expected SHA256 cert error! Wrong length."; exit 1; fi

if test "$ACTUAL_CERT_SHA256" != "$EXPECTED_CERT_SHA256"; then
 echo "Expected SHA256 cert is \"$EXPECTED_CERT_SHA256\", but actual is \"$ACTUAL_CERT_SHA256\"!"; exit 1; fi
