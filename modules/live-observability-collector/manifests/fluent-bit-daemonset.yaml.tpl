apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: ${observability_namespace}
  labels:
    app.kubernetes.io/name: fluent-bit
    app.kubernetes.io/managed-by: bnk-forge
    app.kubernetes.io/part-of: bnk-live-observability
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
        app.kubernetes.io/name: fluent-bit
        app.kubernetes.io/part-of: bnk-live-observability
    spec:
      serviceAccountName: fluent-bit
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: fluent-bit
          image: fluent/fluent-bit:${fluent_bit_version}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 2020
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /api/v1/health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /api/v1/health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
          volumeMounts:
            - name: config
              mountPath: /fluent-bit/etc
            - name: varlog
              mountPath: /var/log
              readOnly: true
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
      terminationGracePeriodSeconds: 10
      volumes:
        - name: config
          configMap:
            name: fluent-bit-config
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
  updateStrategy:
    type: RollingUpdate
