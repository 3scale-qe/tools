---
apiVersion: v1
kind: Secret
metadata:
  name: minio
stringData:
  rootPassword: ${MINIO_SECRET_KEY}
  rootUser: ${MINIO_ACCESS_KEY}
