#!/bin/bash
# Get a root shell in the running claude-sandbox container

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --name NAME        Container name (default: claude-sandbox)
  -h, --help             Show this help

Environment variables:
  CLAUDE_SANDBOX_CONTAINER
EOF
    exit 0
}

CONTAINER_NAME="${CLAUDE_SANDBOX_CONTAINER:-claude-sandbox}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            CONTAINER_NAME="$2"
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
    echo "Start it first with: ./run.sh -n $CONTAINER_NAME"
    exit 1
fi

exec podman exec -it --user 0 "$CONTAINER_NAME" bash
