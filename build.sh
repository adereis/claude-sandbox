#!/bin/bash
# Build the claude-sandbox container image

set -e

cd "$(dirname "$0")"

IMAGE_NAME="${CLAUDE_SANDBOX_IMAGE:-claude-sandbox}"

echo "Building $IMAGE_NAME image..."
podman build -t "$IMAGE_NAME" .

echo ""
echo "Build complete. Run with: ./run.sh"
