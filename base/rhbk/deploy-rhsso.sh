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

function getOCPVersion {
  oc get clusterversion version -o jsonpath='{.status.desired.version}'
}

function isOCPPreview {
  local version
  version=$(getOCPVersion)
  echo "$version" | grep -qiE '\-(rc|er|ec)'
}

function setupCatalogSourceForPreview {
  local version major minor catalog_version
  version=$(getOCPVersion)
  major="${version%%.*}"
  minor="${version#*.}"; minor="${minor%%.*}"

  # For 5.0 preview, use 4.22. For other previews, use previous minor version
  if [[ "$major" -eq 5 && "$minor" -eq 0 ]]; then
    catalog_version="4.22"
  else
    catalog_version="${major}.$((minor - 1))"
  fi

  echo "OCP preview version detected (${version}), using catalog source from OCP v${catalog_version}"

  cat <<EOF | oc apply -n "${NAMESPACE}" -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operators-prev
spec:
  displayName: Red Hat Operators v${catalog_version}
  image: registry.redhat.io/redhat/redhat-operator-index:v${catalog_version}
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

  if ! timeout 120 bash -c "until oc get catalogsource redhat-operators-prev -n '${NAMESPACE}' -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null | grep -q 'READY'; do sleep 5; done"; then
    echo "ERROR: CatalogSource redhat-operators-prev did not become READY within 120s" >&2
    return 1
  fi
}

function deployRHBK {
  <"${FILE_ROOT}"/db-credentials.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  <"${FILE_ROOT}"/operator-group.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -

  export RHBK_CATALOG_SOURCE="redhat-operators"
  export RHBK_CATALOG_NS="openshift-marketplace"
  if isOCPPreview; then
    setupCatalogSourceForPreview
    RHBK_CATALOG_SOURCE="redhat-operators-prev"
    RHBK_CATALOG_NS="${NAMESPACE}"
  fi

  <"${FILE_ROOT}"/keycloak-subscription.yaml.tpl envsubst | oc apply -n "${NAMESPACE}" -f -
  oc wait -n "${NAMESPACE}" --for=jsonpath='{.status.installPlanRef.name}' subscription rhbk-operator --timeout="$TIMEOUT_TIME"s
  oc wait -n "${NAMESPACE}" --for=condition=Installed installplan --all --timeout="$TIMEOUT_TIME"s

  oc apply -n "${NAMESPACE}" -f "${FILE_ROOT}"/rhbk-db.yaml
  oc create -n "${NAMESPACE}" secret generic rhbk-admin --from-literal username="${ADMIN_USERNAME}" --from-literal password="${ADMIN_PASSWORD}" --dry-run=client -o yaml | oc apply -f -

  # Check if keycloak-tls secret exists in infra-3scale (pre-created by create-rhbk-tls.sh with unique cert)
  # This avoids HTTP/2 connection coalescing issues when using the same wildcard cert as ingress
  if oc -n infra-3scale get secret keycloak-tls &>/dev/null; then
    echo "Using existing keycloak-tls secret from infra-3scale (pre-created with unique certificate)"
    tmpdir="$(mktemp -d)"
    oc -n infra-3scale extract secret/keycloak-tls --confirm --to="$tmpdir"
    oc -n "${NAMESPACE}" create secret tls keycloak-tls --cert="$tmpdir/tls.crt" --key="$tmpdir/tls.key" --dry-run=client -o yaml | oc apply -f -
    rm -rf "$tmpdir"
  else
    echo "No keycloak-tls secret found in infra-3scale, extracting from ingress controller"
    ING_SECRET=$(oc -n openshift-ingress-operator get ingresscontroller default -o jsonpath='{.spec.defaultCertificate.name}')
    if [ -z "$ING_SECRET" ]; then ING_SECRET="router-certs-default"; fi
    tmpdir="$(mktemp -d)"
    oc -n openshift-ingress extract secret/"$ING_SECRET" --confirm --to="$tmpdir"
    oc -n "${NAMESPACE}" create secret tls keycloak-tls --cert="$tmpdir/tls.crt" --key="$tmpdir/tls.key" --dry-run=client -o yaml | oc apply -f -
    rm -rf "$tmpdir"
  fi

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
