# Claude Sandbox - Developer Guide

## Architecture

This project creates an isolated Podman container for running Claude Code with full autonomous permissions. The design prioritizes:

1. **UID preservation** - Uses `--userns=keep-id` so host file ownership works inside the container
2. **Minimal privilege** - Container runs as user, root access via separate exec
3. **Ephemeral by default** - `--rm` flag; explicit save step required for persistence

## Key Design Decisions

### Why --userns=keep-id?

Without it, the container's internal UID doesn't match host file ownership, causing permission errors on mounted volumes (especially `~/.claude` which contains runtime state).

### Why separate root-shell.sh?

The main container runs as the user's UID for file permission compatibility. Root operations (package installation) require a separate exec with `--user 0`. This keeps the normal workflow unprivileged while allowing administrative tasks.

### Why --rm by default?

Forces explicit decisions about persistence. Users must run `save-image.sh` to keep changes, preventing accidental state accumulation.

## File Overview

```
Containerfile          # Image definition (Fedora 42 base)
bashrc                 # Shell configuration copied into image
run.sh                 # Main entry point, sets up mounts and user mapping
root-shell.sh          # Exec into running container as root
save-image.sh          # Commit container state to image
build.sh               # Rebuild image from Containerfile
claude-sandbox.env.example  # Template for user environment config
```

## Modification Patterns

### Adding new base packages

Edit the `RUN dnf install` blocks in `Containerfile`, then rebuild:

```dockerfile
RUN dnf install -y \
    your-package \
    && dnf clean all
```

### Adding new volume mounts

Edit `run.sh`, add to the `VOLUMES` array:

```bash
VOLUMES+=(
    -v "$HOME/.some-config:/home/claude/.some-config:ro,z"
)
```

Use `:ro` for read-only, `:z` for SELinux relabeling.

### Adding environment variables

For build-time: Add `ENV` directive in Containerfile.
For runtime: Add to `bashrc` or instruct users to add to `~/.claude-sandbox.env`.

### Changing the base image

Update the `FROM` line in Containerfile. Adjust package manager commands (dnf → apt-get, etc.) accordingly.

## Environment Variable Hierarchy

1. Host environment (passed via `-e` flags)
2. Container's `bashrc`
3. User's `~/.claude-sandbox.env` (sourced last, can override)

## Common Issues

### SELinux denials

The `:z` volume flag handles most cases. For persistent issues, check `ausearch -m avc -ts recent`.

### Container name conflicts

If `./run.sh` fails with "container already exists", either:
- Stop the existing container: `podman stop claude-sandbox`
- Use a different name: `CLAUDE_SANDBOX_CONTAINER=sandbox2 ./run.sh`
