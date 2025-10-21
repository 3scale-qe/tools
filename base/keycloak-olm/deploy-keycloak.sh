#!/bin/bash

set -exo pipefail
command -v envsubst

TIMEOUT_TIME="${TIMEOUT_TIME:=125}"
CTL="${CTL:=kubectl}"
RESOURCES="${BASH_SOURCE%/*}"/resources

NAMESPACE="${NAMESPACE:=tools}"

export NAMESPACE

function set_kubectl_context {
  $CTL config set-cluster ctx --server=https://kubernetes.default --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  $CTL config set-credentials user --token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  $CTL config set-context ctx --user=user --cluster=ctx
  $CTL config use-context ctx
}

function deploy_keycloak {
  # subscribe to the keycloak operator
  <"${RESOURCES}"/operator-group.yaml.tpl envsubst | ${CTL} apply -n "${NAMESPACE}" -f -
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/keycloak-subscription.yaml
  $CTL wait -n "${NAMESPACE}" --for=jsonpath=status.installPlanRef.name subscription keycloak-operator --timeout="$TIMEOUT_TIME"s
  $CTL wait -n "${NAMESPACE}" installplan "$($CTL get -n "${NAMESPACE}" subscription keycloak-operator -o=jsonpath='{.status.installPlanRef.name}')" --for=condition=Installed --timeout="$TIMEOUT_TIME"s

  # create Keycloak CRD and Keycloak service of load-balancer type
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/keycloak.yaml
  $CTL apply -n "${NAMESPACE}" -f "${RESOURCES}"/load-balancer-service.yaml

  # create secret named `credential-sso` from admin credentials for compatibility with how testsuite is working
  timeout "$TIMEOUT_TIME" grep -qm1 '^secret/keycloak-initial-admin$' <($CTL get secret -w -n "${NAMESPACE}" -o name)
  ADMIN_USERNAME="$($CTL get secret keycloak-initial-admin -o jsonpath='{.data.username}' | base64 -d)"
  ADMIN_PASSWORD="$($CTL get secret keycloak-initial-admin -o jsonpath='{.data.password}' | base64 -d)"
  $CTL create secret generic credential-sso --from-literal=ADMIN_USERNAME="${ADMIN_USERNAME}" --from-literal=ADMIN_PASSWORD="${ADMIN_PASSWORD}"
}

if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then  # if running inside kubernetes pod
    NAMESPACE="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
    set_kubectl_context
fi

deploy_keycloak
