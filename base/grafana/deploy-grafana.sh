#!/bin/bash

set -exuo pipefail
command -v envsubst

FILE_ROOT=${BASH_SOURCE%/*}
NAMESPACE=${NAMESPACE:=tools}

export FILE_ROOT NAMESPACE

# make sure user-workloads are enabled
USER_WORKLOADS=$(oc get cm/cluster-monitoring-config -n openshift-monitoring -ojsonpath='{.data.config\.yaml}')

if ! [ "$USER_WORKLOADS" = "enableUserWorkload: true" ]; then
    echo "User Workload is not enabled"
    exit ;
fi

envsubst < "${FILE_ROOT}"/operator-group.yaml | oc apply -n "${NAMESPACE}" -f -
oc apply -f "${FILE_ROOT}"/subscription.yaml -n ${NAMESPACE}

oc wait -n "${NAMESPACE}" --for=jsonpath=status.installPlanRef.name subscription grafana-operator --timeout=120s
oc wait -n "${NAMESPACE}" installplan "$(oc get -n "${NAMESPACE}" subscription grafana-operator -o=jsonpath='{.status.installPlanRef.name}')" --for=condition=Installed --timeout=120s

oc -n "$NAMESPACE" apply -f "$FILE_ROOT"/grafana.yaml

oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-sa -n "$NAMESPACE"

TOKEN="$(oc serviceaccounts new-token grafana-sa -n "$NAMESPACE")"
THANOS_URL="$(oc get route/thanos-querier -n openshift-monitoring -ojsonpath='{.spec.host}')"
export TOKEN THANOS_URL

envsubst < "$FILE_ROOT"/grafanadatasource.yaml | oc -n "$NAMESPACE" apply -f -

unset TOKEN

