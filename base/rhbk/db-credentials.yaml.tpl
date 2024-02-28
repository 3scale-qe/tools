---
apiVersion: v1
kind: Secret
metadata:
  name: rhbk-db-secret
stringData:
  username: ${DB_USERNAME}
  password: ${DB_PASSWORD}
  db_name: "rhbk"
type: Opaque
