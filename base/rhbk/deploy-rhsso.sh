#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME="${TIMEOUT_TIME:=300}"
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
  oc create -n "${NAMESPACE}" secret generic rhbk-admin --from-literal username="${ADMIN_USERNAME}" --from-literal password="${ADMIN_PASSWORD}" --dry-run=client -o yaml | oc apply -f -

  ING_SECRET=$(oc -n openshift-ingress-operator get ingresscontroller default -o jsonpath='{.spec.defaultCertificate.name}')
  if [ -z "$ING_SECRET" ]; then ING_SECRET="router-certs-default"; fi
  tmpdir="$(mktemp -d)"
  oc -n openshift-ingress extract secret/"$ING_SECRET" --confirm --to="$tmpdir"
  oc -n "${NAMESPACE}" create secret tls keycloak-tls --cert="$tmpdir/tls.crt" --key="$tmpdir/tls.key" --dry-run=client -o yaml | oc apply -f -
  rm -rf "$tmpdir"

  APPS_URL=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
  FQDN="ssl-rhbk-${NAMESPACE}.${APPS_URL}" \
      <"${FILE_ROOT}"/sso-keycloak.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -

  timeout "$TIMEOUT_TIME" bash -c "oc get statefulset -w -n ${NAMESPACE} -o name | grep -qm1 '^statefulset.apps/rhbk$'"
  oc rollout -n "${NAMESPACE}" status statefulset/rhbk --timeout="$TIMEOUT_TIME"s

  oc create --namespace "${NAMESPACE}" route passthrough ssl-rhbk --service rhbk-service --port https --dry-run=client -o yaml | oc apply -f -
  oc create --namespace "${NAMESPACE}" route passthrough ssl-rhbk-management --service rhbk-service --port management --dry-run=client -o yaml | oc apply -f -

  oc rsh -n "${NAMESPACE}" statefulsets/rhbk bash -c '/opt/keycloak/bin/kc.sh build --health-enabled=true'

  echo -e 'RHBK v26 installed'

}

deployRHBK
