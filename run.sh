#!/bin/bash
# Run claude-sandbox container with projects mounted

set -e

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [-- COMMAND]

Options:
  -n, --name NAME              Container name (default: claude-sandbox)
  -i, --image IMAGE            Image name (default: claude-sandbox)
  -p, --projects DIR           Projects directory to mount (default: ~/projects)
  --cap-add CAP                Add Linux capability (can be used multiple times)
  --network-unrestricted       Disable network filtering (allow all outbound)
  --network-whitelist FILE     Additional network domain whitelist (appended to defaults)
  --network-allow DOMAIN       Allow an extra network domain (can be used multiple times)
  -h, --help                   Show this help

Environment variables:
  CLAUDE_SANDBOX_CONTAINER, CLAUDE_SANDBOX_IMAGE, CLAUDE_SANDBOX_PROJECTS

Examples:
  ./run.sh                              # Start with defaults (network filtered)
  ./run.sh -n myproject                 # Custom container name
  ./run.sh -n dev -p ~/work/project     # Custom name and projects dir
  ./run.sh --network-allow jira.example.com  # Allow an extra network domain
  ./run.sh --network-whitelist ~/my-domains.conf  # Custom domain whitelist file
  ./run.sh --network-unrestricted       # Disable network filtering
  ./run.sh -- claude --dangerously-skip-permissions
EOF
    exit 0
}

# Defaults (env vars take precedence, CLI overrides both)
IMAGE_PREFIX="claude-sandbox"
IMAGE_NAME="${CLAUDE_SANDBOX_IMAGE:-$IMAGE_PREFIX/default}"
CONTAINER_NAME="${CLAUDE_SANDBOX_CONTAINER:-claude-sandbox}"
PROJECTS_DIR="${CLAUDE_SANDBOX_PROJECTS:-$HOME/projects}"
CAP_ARGS=()
UNRESTRICTED_NETWORK=0
CUSTOM_WHITELIST=""
EXTRA_DOMAINS=()

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
        -p|--projects)
            PROJECTS_DIR="$2"
            shift 2
            ;;
        --cap-add)
            CAP_ARGS+=(--cap-add "$2")
            shift 2
            ;;
        --network-unrestricted)
            UNRESTRICTED_NETWORK=1
            shift
            ;;
        --network-whitelist)
            CUSTOM_WHITELIST="$2"
            shift 2
            ;;
        --network-allow)
            EXTRA_DOMAINS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Validate conflicting network options
if [ "$UNRESTRICTED_NETWORK" = "1" ] && { [ -n "$CUSTOM_WHITELIST" ] || [ ${#EXTRA_DOMAINS[@]} -gt 0 ]; }; then
    echo "Error: --network-unrestricted cannot be combined with --network-whitelist or --network-allow" >&2
    exit 1
fi

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

# Pass through authentication and configuration environment variables
ENV_ARGS=()

# Claude/Anthropic variables (API, Vertex, Bedrock, Foundry)
for var in $(env | grep -E '^(ANTHROPIC_|CLAUDE_CODE_|CLOUD_ML_)' | cut -d= -f1); do
    ENV_ARGS+=(-e "$var")
done

# AWS credentials (for Bedrock)
for var in $(env | grep -E '^AWS_' | cut -d= -f1); do
    ENV_ARGS+=(-e "$var")
done

# Azure credentials (for Foundry)
for var in $(env | grep -E '^AZURE_' | cut -d= -f1); do
    ENV_ARGS+=(-e "$var")
done

# Google Cloud credentials (for Vertex AI)
for var in $(env | grep -E '^(GOOGLE_|GCLOUD_)' | cut -d= -f1); do
    ENV_ARGS+=(-e "$var")
done

# Proxy settings — if host has a proxy, pass it so the entrypoint uses it
# instead of starting tinyproxy (avoids proxy-over-proxy)
for var in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy; do
    if [ -n "${!var}" ]; then
        ENV_ARGS+=(-e "CLAUDE_SANDBOX_EXTERNAL_PROXY=${!var}")
        break
    fi
done
for var in NO_PROXY no_proxy; do
    if [ -n "${!var}" ]; then
        ENV_ARGS+=(-e "$var")
    fi
done

# Network filtering options
if [ "$UNRESTRICTED_NETWORK" = "1" ]; then
    ENV_ARGS+=(-e "CLAUDE_SANDBOX_UNRESTRICTED_NETWORK=1")
fi

if [ -n "$CUSTOM_WHITELIST" ]; then
    if [ ! -f "$CUSTOM_WHITELIST" ]; then
        echo "Whitelist file not found: $CUSTOM_WHITELIST" >&2
        exit 1
    fi
    VOLUMES+=(-v "$CUSTOM_WHITELIST:/home/claude/.claude-sandbox-whitelist.conf:ro,z")
fi

if [ ${#EXTRA_DOMAINS[@]} -gt 0 ]; then
    DOMAINS_CSV=$(IFS=,; echo "${EXTRA_DOMAINS[*]}")
    ENV_ARGS+=(-e "CLAUDE_SANDBOX_EXTRA_DOMAINS=$DOMAINS_CSV")
fi

echo "Starting container '$CONTAINER_NAME' from image '$IMAGE_NAME'..."
echo "Mounting: $PROJECTS_DIR -> /home/claude/projects"
[ -d "$HOME/.config/gcloud" ] && echo "Mounting: ~/.config/gcloud (read-only)"
if [ "$UNRESTRICTED_NETWORK" = "1" ]; then
    echo "Network: unrestricted (filtering disabled)"
else
    echo "Network: filtered (whitelist proxy)"
    [ -n "$CUSTOM_WHITELIST" ] && echo "  Custom whitelist: $CUSTOM_WHITELIST"
    [ ${#EXTRA_DOMAINS[@]} -gt 0 ] && echo "  Extra domains: ${EXTRA_DOMAINS[*]}"
fi
echo "(First run may be slow due to SELinux relabeling)"
echo ""

exec podman run -it --rm \
    --name "$CONTAINER_NAME" \
    --userns=keep-id \
    --user "$(id -u):$(id -g)" \
    "${CAP_ARGS[@]}" \
    -e HOME=/home/claude \
    -w /home/claude/projects \
    "${VOLUMES[@]}" \
    "${ENV_ARGS[@]}" \
    "$IMAGE_NAME" "$@"
