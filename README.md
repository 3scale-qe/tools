#  Scripts for deploying tools needed for proper run of 3scale-tests into OpenShift 

## How to deploy httpbin
1. create new project - ```oc new-project ${NAMESPACE} --skip-config-write=true```
2. add and link credentials secret
   - ```oc create -f ./secret/pull-secret.yaml -n ${NAMESPACE}```
   - ```oc secrets link default pull-secret --for=pull -n ${NAMESPACE}```
   - ```oc secrets link deployer pull-secret --for=pull -n ${NAMESPACE}```
3. create resources through kustomization.yaml - ```oc apply -k base/httpbin/ --namespace ${NAMESPACE}```
