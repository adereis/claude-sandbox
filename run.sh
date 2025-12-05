#!/bin/bash
# Run claude-sandbox container with projects mounted

set -e

IMAGE_NAME="${CLAUDE_SANDBOX_IMAGE:-claude-sandbox}"
CONTAINER_NAME="${CLAUDE_SANDBOX_CONTAINER:-claude-sandbox}"
PROJECTS_DIR="${CLAUDE_SANDBOX_PROJECTS:-$HOME/projects}"

# Ensure required directories exist on host
mkdir -p "$HOME/.claude"
mkdir -p "$PROJECTS_DIR"

# Build volume mounts
VOLUMES=(
    -v "$PROJECTS_DIR:/home/claude/projects:z"
    -v "$HOME/.claude:/home/claude/.claude:z"
)

# Mount gcloud credentials if available (for Vertex AI)
if [ -d "$HOME/.config/gcloud" ]; then
    VOLUMES+=(-v "$HOME/.config/gcloud:/home/claude/.config/gcloud:ro,z")
fi

# Mount custom environment file if present
if [ -f "$HOME/.claude-sandbox.env" ]; then
    VOLUMES+=(-v "$HOME/.claude-sandbox.env:/home/claude/.claude-sandbox.env:ro,z")
fi

# Pass through API key if set
ENV_ARGS=()
if [ -n "$ANTHROPIC_API_KEY" ]; then
    ENV_ARGS+=(-e ANTHROPIC_API_KEY)
fi

exec podman run -it --rm \
    --name "$CONTAINER_NAME" \
    --userns=keep-id \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/claude \
    -w /home/claude/projects \
    "${VOLUMES[@]}" \
    "${ENV_ARGS[@]}" \
    "$IMAGE_NAME" "$@"
