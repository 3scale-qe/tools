#  Scripts for deploying tools needed for proper run of 3scale-tests into OpenShift 

## Project and secrets setup
1. create new project: ```oc new-project ${NAMESPACE} --skip-config-write=true```
2. add and link credentials secret
   - ```oc create -f ./secret/pull-secret.yaml -n ${NAMESPACE}```
   - ```oc secrets link default pull-secret --for=pull -n ${NAMESPACE}```
   - ```oc secrets link deployer pull-secret --for=pull -n ${NAMESPACE}```

## How to deploy httpbin and go-httpbin
   - httpbin: ```oc apply -k base/httpbin/ --namespace ${NAMESPACE}```
   - go-httpbin: ```oc apply -k base/go-httpbin/ --namespace ${NAMESPACE}```
   - OR both ```oc apply -k overlays/all/ --namespace ${NAMESPACE}```

## How to deploy request-bin
   - request-bin: ```oc apply -k base/request-bin/ --namespace ${NAMESPACE}```
