#!/bin/sh
# This is entrypoint script for 3scale-tests `tools` make target

cd `dirname $0`

SHARED_NAMESPACE="${SHARED_NAMESPACE:=tools}"

if [ -n "$DOCKERCONFIGJSON" ]; then
	oc get project "$SHARED_NAMESPACE" || oc new-project "$SHARED_NAMESPACE" --skip-config-write=true
	_oc="oc -n $SHARED_NAMESPACE"
	$_oc get secret pull-secret \
		|| ( $_oc create secret generic pull-secret --from-file .dockerconfigjson="$DOCKERCONFIGJSON" --type=kubernetes.io/dockerconfigjson \
			&& $_oc secrets link default pull-secret --for=pull )
fi

oc apply -k overlays/testsuite/ --namespace "${SHARED_NAMESPACE}"

NAMESPACE=$SHARED_NAMESPACE ./base/rhsso/deploy-rhsso.sh

oc apply -k overlays/exclusive/ --namespace "${THREESCALE_NAMESPACE:=3scale}"
