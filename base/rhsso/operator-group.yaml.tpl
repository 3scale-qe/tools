---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${TARGET_NAMESPACE}
spec:
  targetNamespaces:
    - ${TARGET_NAMESPACE}
