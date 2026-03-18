#!/usr/bin/env bash
set -euo pipefail

#
# Builds and pushes the octobercms/october all-in-one Docker image.
#
# Usage:
#   ./publish.sh                              # Build + push octobercms/october:latest
#   ./publish.sh octobercms/october-staging   # Build + push to a custom image name
#

IMAGE="${1:-octobercms/october:latest}"

# Append :latest if no tag specified
if [[ "$IMAGE" != *:* ]]; then
    IMAGE="$IMAGE:latest"
fi

cd "$(dirname "$0")"

echo "Building $IMAGE ..."
docker build -t "$IMAGE" .

echo ""
echo "Pushing $IMAGE ..."
docker push "$IMAGE"

echo ""
echo "Done. Published $IMAGE"
