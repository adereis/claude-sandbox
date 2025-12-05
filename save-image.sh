#!/bin/bash
# Commit the running container state to the image
# Run this after installing packages you want to keep

IMAGE_NAME="${CLAUDE_SANDBOX_IMAGE:-claude-sandbox}"
CONTAINER_NAME="${CLAUDE_SANDBOX_CONTAINER:-claude-sandbox}"

if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    echo "Container '$CONTAINER_NAME' is not running."
    exit 1
fi

echo "Committing current container state to $IMAGE_NAME:latest..."
podman commit "$CONTAINER_NAME" "$IMAGE_NAME:latest"

echo "Done. New packages will persist in future runs."
