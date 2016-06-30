#!/bin/bash

function err() {
  echo "ERR: $* exiting..."
  exit 1
}

function usage() {
  echo "USAGE: $0 [path to pubkey] [path to pubkey] ..."
  exit 0
}

function is_key_type_valid() {
  local KEY_TYPE="$1"
  local IS_VALID=1

  [ -z "$KEY_TYPE" ] && err "You must pass a non-empty vlaue to is_key_type_valid"

  for VALID_TYPE in "${VALID_TYPES[@]}"
  do
    if [ "$KEY_TYPE" == "$VALID_TYPE" ]; then
      IS_VALID=0
      break
    fi
  done

  return $IS_VALID
}

function is_key_valid() {
  local PUBKEY="$1"

  [ -z "$PUBKEY" ] && err "You must pass a non-empty value to is_key_valid"

  local KEY_FORMAT=$(ssh-keygen -ef $PUBKEY -m PKCS8 2>>/dev/null)

  [ -z "$KEY_FORMAT" ] && return 1

  echo "$KEY_FORMAT" | ssh-keygen -i -f /dev/stdin -m PKCS8 >>/dev/null
}

function attempt_pubkey_fix() {

  for VALID_TYPE in "${VALID_TYPES[@]}"
  do
    KEY_TYPE="$VALID_TYPE"
    TMP_PUBKEY_FILE="${PUBKEY}.${KEY_TYPE}"

    echo "${KEY_TYPE} ${KEY_DATA} ${KEY_COMMENT}" > ${TMP_PUBKEY_FILE}

    is_key_valid "$TMP_PUBKEY_FILE"
    if [ $? -eq 0 ]; then
      echo "SUCCESS: I converted the pubkey '${TMP_PUBKEY_FILE}' keytype to '${KEY_TYPE}'"
      mv ${TMP_PUBKEY_FILE} ${PUBKEY}
    else
      rm -f ${TMP_PUBKEY_FILE}
    fi
  done

}

VALID_TYPES=(ssh-dss ssh-rsa ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521 ssh-ed25519)

PUB_KEY_FILE=($@)

[ ${#PUB_KEY_FILE[@]} -eq 0 ] && usage

for PUBKEY in "${PUB_KEY_FILE[@]}"
  do
    KEY_CONTENT=$(cat $PUBKEY)
    set $KEY_CONTENT --
    KEY_TYPE=$1
    KEY_DATA=$2
    KEY_COMMENT=$3

    [ -z "$KEY_TYPE" ] && err "The first field in the file ${PUBKEY} should not be blank"
    [ -z "$KEY_DATA" ] && err "The second field in the file ${PUBKEY} should not be blank"
    [ -z "$KEY_COMMENT" ] && err "The third field in the file ${PUBKEY} should not be blank"

    is_key_type_valid "$KEY_TYPE"
    if [ $? -ne 0 ]; then
      echo "The key type '${KEY_TYPE}' is not a valid type, valid values are [${VALID_TYPES[@]}]... Trying valid key types... hang tight"
      attempt_pubkey_fix
    else
      is_key_valid "$PUBKEY" || attempt_pubkey_fix
    fi
done
