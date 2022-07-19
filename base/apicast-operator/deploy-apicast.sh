#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME=5   # each 5sec: 5 * 5sec = 25sec
FILE_ROOT=${BASH_SOURCE%/*}
NAMESPACE=${NAMESPACE:="apicast-ga"}

function waitSuccess {
  TIMEOUT=0
  CMD=$*
  until $CMD
  do
    if [[ TIMEOUT -eq TIMEOUT_TIME ]]; then
      echo "Exit due to timeout"
      exit 1
    fi
    TIMEOUT=$((TIMEOUT+1))
    sleep 5
  done
}

function deployApicastOperator {
  oc new-project ${NAMESPACE} --skip-config-write=true || true
  oc kustomize "${FILE_ROOT}"/ | TARGET_NAMESPACE=${NAMESPACE} envsubst | oc apply -f - -n ${NAMESPACE}
  waitSuccess oc wait installplan --all --for=condition=Installed -n ${NAMESPACE}
}

deployApicastOperator
