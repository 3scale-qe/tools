---
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: rhbk
  labels:
    app: rhbk
spec:
  db:
    host: rhbk-db
    passwordSecret:
      key: password
      name: rhbk-db-secret
    usernameSecret:
      key: username
      name: rhbk-db-secret
    vendor: postgres
    database: rhbk
  hostname:
    hostname: ${FQDN}
    strict: false
    strictBackchannel: false
  http:
    httpEnabled: true
    httpPort: 8080
  ingress:
    enabled: false
  unsupported:
    podTemplate:
      spec:
        containers:
          - args:
              - start-dev
  instances: 1
