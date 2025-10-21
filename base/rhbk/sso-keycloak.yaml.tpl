---
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: rhbk
  labels:
    app: rhbk
spec:
  bootstrapAdmin:
    user:
      secret: rhbk-admin
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
    httpsPort: 8443
    tlsSecret: keycloak-tls
  ingress:
    enabled: false
  unsupported:
    podTemplate:
      spec:
        containers:
          - args:
              - start-dev
  instances: 1
