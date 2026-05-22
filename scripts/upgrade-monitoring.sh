#!/bin/bash
helm upgrade kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace monitoring \
  --values infra/base/monitoring/values-prometheus.yaml \
  --set nodeExporter.enabled=true \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=2Gi \
  --reuse-values \
  --wait
