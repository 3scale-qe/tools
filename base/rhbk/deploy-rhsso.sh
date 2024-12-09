#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME="${TIMEOUT_TIME:=125}"
FILE_ROOT="${BASH_SOURCE%/*}"

NAMESPACE="${NAMESPACE:=tools}"
ADMIN_USERNAME="${ADMIN_USERNAME:="admin"}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:="admin"}"

DB_USERNAME="${DB_USERNAME:="dbusername"}"
DB_PASSWORD="${DB_PASSWORD:="dbpassword"}"

export NAMESPACE ADMIN_PASSWORD ADMIN_USERNAME DB_PASSWORD DB_USERNAME

function deployRHBK {
  <"${FILE_ROOT}"/db-credentials.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  <"${FILE_ROOT}"/operator-group.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/keycloak-subscription.yaml
  oc wait -n "${NAMESPACE}" --for=jsonpath='{.status.installPlanRef.name}' subscription rhbk-operator --timeout="$TIMEOUT_TIME"s
  oc wait -n "${NAMESPACE}" --for=condition=Installed installplan --all --timeout="$TIMEOUT_TIME"s

  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/rhbk-db.yaml
  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/no-ssl-sso-route.yaml

  FQDN=$(oc get -n "${NAMESPACE}" route/no-ssl-rhbk -o jsonpath='{.status.ingress[0].host}') \
      <"${FILE_ROOT}"/sso-keycloak.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -

  timeout "$TIMEOUT_TIME" bash -c "oc get statefulset -w -n ${NAMESPACE} -o name | grep -qm1 '^statefulset.apps/rhbk$'"
  oc rollout -n "${NAMESPACE}" status statefulset/rhbk --timeout="$TIMEOUT_TIME"s

  PASSWD=$(oc get secret rhbk-initial-admin -o jsonpath='{.data.password}' -n "${NAMESPACE}" | base64 --decode)

  oc rsh -n "${NAMESPACE}" statefulsets/rhbk bash -c "/opt/keycloak/bin/kcadm.sh update realms/master -s sslRequired=NONE --server http://localhost:8080/ --realm master --user admin --password ${PASSWD} --no-config; /opt/keycloak/bin/kcadm.sh set-password --server http://localhost:8080/ --realm master --user admin --password ${PASSWD} --username admin --new-password ${ADMIN_PASSWORD} --no-config"
  oc patch -n "${NAMESPACE}" secret/rhbk-initial-admin --type json -p '[{"op": "replace", "path": "/data/password", "value":"'$(echo -en "$ADMIN_PASSWORD" | base64 -w0)'"}]'

}

deployRHBK
