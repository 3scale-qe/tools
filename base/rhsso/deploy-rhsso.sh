#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME=25   # each 5sec: 25 * 5sec = 125sec
FILE_ROOT="${BASH_SOURCE%/*}"

NAMESPACE="${NAMESPACE:=tools}"
ADMIN_USERNAME="${ADMIN_USERNAME:="admin"}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:="admin"}"

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

export NAMESPACE ADMIN_PASSWORD ADMIN_USERNAME

function deployRHSSO {
  <"${FILE_ROOT}"/operator-group.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/keycloak-subscription.yaml
  waitSuccess oc wait -n "${NAMESPACE}" installplan --all --for=condition=Installed

  <"${FILE_ROOT}"/credential-sso-secret.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/sso-keycloak.yaml
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/no-ssl-sso-service.yaml
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/no-ssl-sso-route.yaml
  waitSuccess oc rollout -n "${NAMESPACE}" status statefulset/keycloak -w

  oc rsh -n "${NAMESPACE}" statefulset/keycloak bash -c "/opt/eap/bin/kcadm.sh update realms/master -s sslRequired=NONE --server http://localhost:8080/auth --realm master --user ${ADMIN_USERNAME} --password ${ADMIN_PASSWORD} --no-config"
}

deployRHSSO
