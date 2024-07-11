#!/bin/bash

set -exuo pipefail
command -v envsubst

TIMEOUT_TIME="${TIMEOUT_TIME:=125}"
CTL="${CTL:=kubectl}"
RESOURCES="${BASH_SOURCE%/*}"/resources

NAMESPACE="${NAMESPACE:=tools}"
ADMIN_USERNAME="${ADMIN_USERNAME:="admin"}"

export NAMESPACE ADMIN_USERNAME

function set_kubectl_context {
  $CTL config set-cluster ctx --server=https://kubernetes.default --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  $CTL config set-credentials user --token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  $CTL config set-context ctx --user=user --cluster=ctx
  $CTL config use-context ctx
}

function deploy_rhsso {
  <"${RESOURCES}"/operator-group.yaml.tpl envsubst | $CTL apply -n "${NAMESPACE}" -f -
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/keycloak-subscription.yaml
  $CTL wait -n "${NAMESPACE}" --for=jsonpath=status.installPlanRef.name subscription rhsso-operator --timeout="$TIMEOUT_TIME"s
  $CTL wait -n "${NAMESPACE}" installplan "$($CTL get -n "${NAMESPACE}" subscription rhsso-operator -o=jsonpath='{.status.installPlanRef.name}')" --for=condition=Installed --timeout="$TIMEOUT_TIME"s

#   <"${RESOURCES}"/credential-sso-secret.yaml.tpl envsubst | $CTL apply -n "${NAMESPACE}" -f -
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/sso-keycloak.yaml
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/no-ssl-sso-service.yaml
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/no-ssl-sso-route.yaml

  timeout "$TIMEOUT_TIME" grep -qm1 '^statefulset.apps/keycloak$' <($CTL get statefulset -w -n "${NAMESPACE}" -o name)
  $CTL rollout -n "${NAMESPACE}" status statefulset/keycloak --timeout="$TIMEOUT_TIME"s

  ADMIN_PASSWORD="$($CTL get secret credential-sso -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)"
  $CTL exec --stdin --tty statefulset/keycloak -n "${NAMESPACE}" -- /bin/bash -c "/opt/eap/bin/kcadm.sh update realms/master -s sslRequired=NONE --server http://localhost:8080/auth --realm master --user ${ADMIN_USERNAME} --password ${ADMIN_PASSWORD} --no-config"
}

if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
    NAMESPACE="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
    set_kubectl_context  # if running inside kubernetes pod
fi

deploy_rhsso
