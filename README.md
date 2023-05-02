# About

This project is a simple example how to use Jaeger and OpenTelemetry to monitor a Python application (FastAPI).

> Note: This is not meant to be a production ready example so don't threat it as such.

## Requirements

- Docker
- Kind
- kubectl

## Run

```bash
bash setup.sh
```

The above will create a kind cluster named `telemetry` and deploy the following:

- Cert Manager Operator
- Jaeger Operator
- OTEL Operator
- Jaeger Instance
- OTEL Collector
- OTEL Instrumentation
- Build a docker image for the application
- Deploy the application
- Setup port forwarding for Jaeger UI (port 16686) and the application (port 8000)

## Observability Notes

### Python

For python

## References

- https://techblog.cisco.com/blog/getting-started-with-opentelemetry
- https://opentelemetry.io/docs/k8s-operator/automatic/#python
