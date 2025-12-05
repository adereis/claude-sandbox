#!/bin/bash
# Get a root shell in the running claude-sandbox container

CONTAINER_NAME="${CLAUDE_SANDBOX_CONTAINER:-claude-sandbox}"

if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    echo "Container '$CONTAINER_NAME' is not running."
    echo "Start it first with: ./run.sh"
    exit 1
fi

exec podman exec -it --user 0 "$CONTAINER_NAME" bash
