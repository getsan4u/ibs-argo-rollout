#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="rollouts-demo"
INGRESS_NAME="rollouts-demo"

hostname="$(
  kubectl get ingress "$INGRESS_NAME" \
    --namespace "$NAMESPACE" \
    --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'
)"

if [[ -z "$hostname" ]]; then
  echo "ALB hostname is not available yet for ingress ${NAMESPACE}/${INGRESS_NAME}." >&2
  echo "Wait for the AWS Load Balancer Controller to provision the ALB, then try again." >&2
  exit 1
fi

echo "http://${hostname}"
