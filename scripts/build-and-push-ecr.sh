#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_PROFILE="${AWS_PROFILE:-personal-ssg}"
ECR_REPOSITORY="${ECR_REPOSITORY:-364641874932.dkr.ecr.ap-south-1.amazonaws.com/ibs-demo-apps}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"
ECR_REGISTRY="${ECR_REPOSITORY%%/*}"

if [[ "$#" -eq 0 ]]; then
  tags=(blue green)
else
  tags=("$@")
fi

for command in aws docker; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

aws ecr get-login-password --profile "$AWS_PROFILE" --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

for tag in "${tags[@]}"; do
  color="$tag"
  error_rate=""

  case "$tag" in
    blue|green)
      ;;
    bad-green)
      color="green"
      error_rate="15"
      ;;
    *)
      echo "Unsupported image tag: $tag" >&2
      echo "Supported tags: blue, green, bad-green" >&2
      exit 1
      ;;
  esac

  echo "Building and pushing ${ECR_REPOSITORY}:${tag}"
  docker buildx build \
    --platform "$TARGET_PLATFORM" \
    --build-arg "COLOR=${color}" \
    --build-arg "ERROR_RATE=${error_rate}" \
    --tag "${ECR_REPOSITORY}:${tag}" \
    --push \
    "$REPO_ROOT/src"
done
