#!/usr/bin/env bash

set -euo pipefail

kubectl argo rollouts get rollout rollouts-demo -n rollouts-demo --watch
