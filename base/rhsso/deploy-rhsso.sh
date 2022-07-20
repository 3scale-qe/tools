#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME=25   # each 5sec: 25 * 5sec = 125sec
FILE_ROOT=${BASH_SOURCE%/*}

NAMESPACE=${NAMESPACE:=tools}
ADMIN_USERNAME=${ADMIN_USERNAME:="admin"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:="admin"}

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

function deployRHSSO {
  cat ${FILE_ROOT}/operator-group.yaml.tpl | TARGET_NAMESPACE=${NAMESPACE} envsubst | oc apply -f - -n ${NAMESPACE}
  oc apply -f "${FILE_ROOT}"/keycloak-subscription.yaml -n ${NAMESPACE}
  waitSuccess oc wait installplan --all --for=condition=Installed -n ${NAMESPACE}

  cat ${FILE_ROOT}/credential-sso-secret.yaml.tpl | ADMIN_USERNAME=${ADMIN_USERNAME} ADMIN_PASSWORD=${ADMIN_PASSWORD} envsubst | oc apply -f - -n ${NAMESPACE}
  oc apply -f "${FILE_ROOT}"/sso-keycloak.yaml -n ${NAMESPACE}
  oc apply -f "${FILE_ROOT}"/no-ssl-sso-service.yaml -n ${NAMESPACE}
  oc apply -f "${FILE_ROOT}"/no-ssl-sso-route.yaml -n ${NAMESPACE}
  waitSuccess oc rollout status statefulset/keycloak -w -n ${NAMESPACE}

  oc --namespace ${NAMESPACE} rsh statefulset/keycloak bash -c "/opt/eap/bin/kcadm.sh update realms/master -s sslRequired=NONE --server http://no-ssl-sso:8080/auth --realm master --user ${ADMIN_USERNAME} --password ${ADMIN_PASSWORD} --no-config"
}

deployRHSSO
