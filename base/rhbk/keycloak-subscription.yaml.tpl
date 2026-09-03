---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhbk-operator
spec:
  channel: stable-v26
  installPlanApproval: Automatic
  name: rhbk-operator
  source: ${RHBK_CATALOG_SOURCE}
  sourceNamespace: ${RHBK_CATALOG_NS}
