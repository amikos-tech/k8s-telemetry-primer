#!/bin/bash

kind create cluster --name telemetry --wait 5m

kind export kubeconfig --name telemetry

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.1/cert-manager.yaml

kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=webhook \
  --timeout=120s

kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.8.5/install.yaml

kubectl create -f- << EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: audit
  rules:
  - name: check-for-labels
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - "default"
    validate:
      message: "label 'app.kubernetes.io/name' is required"
      pattern:
        metadata:
          labels:
            app.kubernetes.io/name: "?*"
EOF



kubectl create namespace observability
kubectl apply -f  https://github.com/jaegertracing/jaeger-operator/releases/download/v1.42.0/jaeger-operator.yaml -n observability
sleep 5
kubectl wait --namespace observability \
  --for=condition=ready pod \
  --selector=name=jaeger-operator \
  --timeout=120s

kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
EOF


kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml


kubectl wait --namespace opentelemetry-operator-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=opentelemetry-operator \
  --timeout=120s


# kubectl apply -f - <<EOF
# apiVersion: opentelemetry.io/v1alpha1
# kind: OpenTelemetryCollector
# metadata:
#   name: otel
# spec:
#   config: |
#     receivers:
#       otlp:
#         protocols:
#           grpc:
#           http:
#     processors:
#       memory_limiter:
#         check_interval: 1s
#         limit_percentage: 75
#         spike_limit_percentage: 15
#       batch:
#         send_batch_size: 10000
#         timeout: 10s
#     exporters:
#       logging:  
#       jaeger:
#           endpoint: "simplest-collector:14250"
#           tls:
#               insecure: true
#     service:
#       pipelines:
#         traces:
#           receivers: [otlp]
#           processors: []
#           exporters: [jaeger]
# EOF


kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel
spec:
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
          http:
    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 15
      batch:
        send_batch_size: 10000
        timeout: 10s

    exporters:
        logging:
        jaeger:
            endpoint: "simplest-collector:14250"
            tls:
                insecure: true     
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [logging,jaeger]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [logging]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [logging]
EOF

kubectl wait --namespace default \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=otel-collector \
  --timeout=120s

# kubectl apply -f - <<EOF
# apiVersion: opentelemetry.io/v1alpha1
# kind: Instrumentation
# metadata:
#   name: my-instrumentation
# spec:
#   exporter:
#     endpoint: http://otel-collector:4318
#   propagators:
#     - tracecontext
#     - baggage
#     - b3
#   sampler:
#     type: parentbased_traceidratio
#     argument: "0.25"
#   java:
#     image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
#   nodejs:
#     image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
#   python:
#     image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
# EOF


kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: demo-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1"
EOF

docker build -t cladmin/pytest:latest .

kind load docker-image cladmin/pytest:latest --name telemetry


kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
    name: python-fastapi
    labels:
        app: python-fastapi
spec:
    ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
    selector:
        app: python-fastapi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-fastapi
spec:
  selector:
    matchLabels:
      app: python-fastapi
  replicas: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: python-fastapi
        app: python-fastapi
      annotations:
        sidecar.opentelemetry.io/inject: "true"
        instrumentation.opentelemetry.io/inject-python: "true"
    spec:
      containers:
      - name: app
        imagePullPolicy: Never
        image: cladmin/pytest:latest
        ports:
        - containerPort: 8000
EOF

kubectl wait --namespace default \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=python-fastapi \
  --timeout=120s

kubectl port-forward svc/simplest-query 16686:16686 &
kubectl port-forward svc/python-fastapi 8000:8000 &
