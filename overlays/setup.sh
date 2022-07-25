#!/bin/bash

set -exuo pipefail
# requires envsubst

ROOT_PATH=${BASH_SOURCE%/*}/..

TOOLS_NAMESPACE=tools1
APICAST_NAMESPACE=apicast-ga1

function waitSuccess {
  CMD=$*
  until $CMD
  do
    sleep 5
  done
}

function prepareNamespaces {
  oc new-project ${TOOLS_NAMESPACE} --skip-config-write=true || true
  oc create -f ${ROOT_PATH}/secret/pull-secret.yaml -n ${TOOLS_NAMESPACE} || true
  oc secrets link default pull-secret --for=pull -n ${TOOLS_NAMESPACE} || true
  oc secrets link deployer pull-secret --for=pull -n ${TOOLS_NAMESPACE} || true
  oc new-project ${APICAST_NAMESPACE} --skip-config-write=true || true
}

function deployApicastOperator {
  oc kustomize ${ROOT_PATH}/base/apicast-operator/ | TARGET_NAMESPACE=${APICAST_NAMESPACE} envsubst | oc apply -f - -n ${APICAST_NAMESPACE}
}

function deployRHSSO {
  cat ${ROOT_PATH}/base/rhsso/operator-group.yaml | TARGET_NAMESPACE=${TOOLS_NAMESPACE} envsubst | oc apply -f - -n ${TOOLS_NAMESPACE}
  oc create -f ${ROOT_PATH}/base/rhsso/keycloak-subscription.yaml -n ${TOOLS_NAMESPACE}
  waitSuccess oc wait installplan --all --for=condition=Installed -n ${TOOLS_NAMESPACE}

  cat ${ROOT_PATH}/base/rhsso/credential-sso-secret.yaml | ADMIN_USERNAME=${ADMIN_USERNAME} ADMIN_PASSWORD=${ADMIN_PASSWORD} envsubst | oc apply -f - -n ${TOOLS_NAMESPACE}
  oc create -f ${ROOT_PATH}/base/rhsso/sso-keycloak.yaml -n ${TOOLS_NAMESPACE}
  waitSuccess oc rollout status statefulset/keycloak -w -n ${TOOLS_NAMESPACE}

  oc apply -f ${ROOT_PATH}/base/rhsso/no-ssl-sso-service.yaml -n ${TOOLS_NAMESPACE}
  oc apply -f ${ROOT_PATH}/base/rhsso/no-ssl-sso-route.yaml -n ${TOOLS_NAMESPACE}

  oc --namespace ${TOOLS_NAMESPACE} rsh statefulset/keycloak bash -c "/opt/eap/bin/kcadm.sh update realms/master -s sslRequired=NONE --server http://no-ssl-sso:8080/auth --realm master --user ${ADMIN_USERNAME} --password ${ADMIN_PASSWORD} --no-config"
}
