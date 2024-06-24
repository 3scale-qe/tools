---
apiVersion: v1
kind: Secret
metadata:
  name: credential-sso
stringData:
  ADMIN_USERNAME: ${ADMIN_USERNAME}
  ADMIN_PASSWORD: ${ADMIN_PASSWORD}
type: Opaque
