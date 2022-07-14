#  Scripts for deploying tools needed for proper run of 3scale-tests into OpenShift 

## Environment setup

### Project creation

You can use already existing or new project for the services deployment. You can create a new project through CLI:
```oc new-project ${NAMESPACE} --skip-config-write=true```

### Secrets

If you have ```pull-secret``` for accessing private registries, you can link it up with service accounts:
```bash
oc create -f secret/pull-secret.yaml --namespace ${NAMESPACE}
oc secrets link default pull-secret --for=pull --namespace ${NAMESPACE}
oc secrets link deployer pull-secret --for=pull --namespace ${NAMESPACE}
```

## Services deployment

### Individual service deployment
`oc apply -k base/${SERVICE_NAME}/ --namespace ${NAMESPACE}`

### All services deployment
`oc apply -k overlays/all/ --namespace ${NAMESPACE}`
