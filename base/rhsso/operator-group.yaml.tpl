---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${NAMESPACE}
spec:
  targetNamespaces:
    - ${NAMESPACE}
