#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUSTOMIZATION_FILE="$REPO_ROOT/deploy/overlays/prod/kustomization.yaml"

if grep -Eq '^[[:space:]]*newTag:[[:space:]]*green[[:space:]]*$' "$KUSTOMIZATION_FILE"; then
  echo "The prod image tag is already green."
elif grep -Eq '^[[:space:]]*newTag:[[:space:]]*blue[[:space:]]*$' "$KUSTOMIZATION_FILE"; then
  sed -i.bak -E 's/^([[:space:]]*newTag:)[[:space:]]*blue[[:space:]]*$/\1 green/' "$KUSTOMIZATION_FILE"
  rm "$KUSTOMIZATION_FILE.bak"
  echo "Updated the prod image tag from blue to green."
else
  echo "Expected to find 'newTag: blue' in $KUSTOMIZATION_FILE." >&2
  exit 1
fi

git -C "$REPO_ROOT" diff -- deploy/overlays/prod/kustomization.yaml

cat <<'EOF'

Next steps:
  git add deploy/overlays/prod/kustomization.yaml
  git commit -m "Promote rollouts-demo from blue to green"
  git push
EOF
