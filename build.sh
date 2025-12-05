#!/bin/bash
# Build the claude-sandbox container image

set -e

cd "$(dirname "$0")"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -i, --image IMAGE      Image name (default: claude-sandbox)
  -h, --help             Show this help

Environment variables:
  CLAUDE_SANDBOX_IMAGE
EOF
    exit 0
}

IMAGE_NAME="${CLAUDE_SANDBOX_IMAGE:-claude-sandbox}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            IMAGE_NAME="$2"
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

echo "Building $IMAGE_NAME image..."
podman build -t "$IMAGE_NAME" .

echo ""
echo "Build complete. Run with: ./run.sh"
