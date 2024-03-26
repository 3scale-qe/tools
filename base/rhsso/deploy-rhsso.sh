#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME="${TIMEOUT_TIME:=125}"
FILE_ROOT="${BASH_SOURCE%/*}"

NAMESPACE="${NAMESPACE:=tools}"
ADMIN_USERNAME="${ADMIN_USERNAME:="admin"}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:="admin"}"

export NAMESPACE ADMIN_PASSWORD ADMIN_USERNAME

function deployRHSSO {
  <"${FILE_ROOT}"/operator-group.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/keycloak-subscription.yaml
  oc wait -n "${NAMESPACE}" --for=jsonpath=status.installPlanRef.name subscription rhsso-operator --timeout="$TIMEOUT_TIME"s
  oc wait -n "${NAMESPACE}" --for=condition=Installed installplan --all --timeout="$TIMEOUT_TIME"s

  <"${FILE_ROOT}"/credential-sso-secret.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/sso-keycloak.yaml
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/no-ssl-sso-service.yaml
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/no-ssl-sso-route.yaml

  timeout "$TIMEOUT_TIME" bash -c "oc get statefulset -w -n ${NAMESPACE} -o name | grep -qm1 '^statefulset.apps/keycloak$'"
  oc rollout -n "${NAMESPACE}" status statefulset/keycloak --timeout="$TIMEOUT_TIME"s

  oc rsh -n "${NAMESPACE}" statefulset/keycloak bash -c "/opt/eap/bin/kcadm.sh update realms/master -s sslRequired=NONE --server http://localhost:8080/auth --realm master --user ${ADMIN_USERNAME} --password ${ADMIN_PASSWORD} --no-config"
}

deployRHSSO
