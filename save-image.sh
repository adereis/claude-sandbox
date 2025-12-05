#!/bin/bash
# Commit the running container state to the image
# Run this after installing packages you want to keep

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --name NAME        Container name (default: claude-sandbox)
  -i, --image IMAGE      Image name to save to (default: claude-sandbox)
  -h, --help             Show this help

Environment variables:
  CLAUDE_SANDBOX_CONTAINER, CLAUDE_SANDBOX_IMAGE
EOF
    exit 0
}

IMAGE_PREFIX="claude-sandbox"
IMAGE_NAME="${CLAUDE_SANDBOX_IMAGE:-$IMAGE_PREFIX/default}"
CONTAINER_NAME="${CLAUDE_SANDBOX_CONTAINER:-claude-sandbox}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$IMAGE_PREFIX/$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    echo "Container '$CONTAINER_NAME' is not running."
    exit 1
fi

echo "Committing current container state to $IMAGE_NAME:latest..."
podman commit "$CONTAINER_NAME" "$IMAGE_NAME:latest"

echo "Done. New packages will persist in future runs."
