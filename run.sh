#!/bin/sh
# This is entrypoint script for 3scale-tests `tools` make target

cd `dirname $0`

for SERVICE_NAME in echo-api fuse-proxy go-httpbin jaeger mockserver; do
	oc apply -k base/${SERVICE_NAME}/ --namespace ${SHARED_NAMESPACE:=tools}
done

NAMESPACE=$SHARED_NAMESPACE ./base/rhsso/deploy-rhsso.sh
