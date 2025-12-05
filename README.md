# Claude Sandbox

A containerized environment for running Claude Code in autonomous mode. Provides isolation for safe experimentation while preserving access to your projects and credentials.

## Requirements

- Podman (tested on Fedora with rootless Podman)
- Claude Code authentication (Anthropic API key or Vertex AI credentials)

## Quick Start

```bash
# Build the container
./build.sh

# Run the container
./run.sh

# Inside the container, start Claude
claude --dangerously-skip-permissions
```

## Directory Structure

```
~/projects/          → /home/claude/projects    (read-write)
~/.claude/           → /home/claude/.claude     (read-write)
~/.config/gcloud/    → /home/claude/.config/gcloud (read-only, if exists)
```

## Authentication

### Anthropic API

Set `ANTHROPIC_API_KEY` in your host environment before running:

```bash
export ANTHROPIC_API_KEY=sk-...
./run.sh
```

### Vertex AI

1. Authenticate on the host:
   ```bash
   gcloud auth application-default login
   ```

2. Create `~/.claude-sandbox.env`:
   ```bash
   export CLAUDE_CODE_USE_VERTEX=1
   export CLOUD_ML_REGION=us-east5
   export ANTHROPIC_VERTEX_PROJECT_ID=your-project-id
   ```

The gcloud credentials are mounted automatically if present.

## Installing Packages

Packages installed at runtime are lost when the container exits. To persist them:

1. Start the container: `./run.sh`
2. In another terminal, get a root shell: `./root-shell.sh`
3. Install packages: `dnf install -y <packages>`
4. Save to image: `./save-image.sh`

For frequently-used packages, add them to the Containerfile and rebuild.

## Configuration

Environment variables (set on host or in `~/.claude-sandbox.env`):

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_SANDBOX_IMAGE` | `claude-sandbox/default` | Container image name |
| `CLAUDE_SANDBOX_CONTAINER` | `claude-sandbox` | Container instance name |
| `CLAUDE_SANDBOX_PROJECTS` | `$HOME/projects` | Host projects directory |
| `ANTHROPIC_API_KEY` | - | Anthropic API key |

## Scripts

All scripts support `-h` or `--help` for usage information.

### run.sh

```
Usage: run.sh [OPTIONS] [-- COMMAND]

Options:
  -n, --name NAME        Container name (default: claude-sandbox)
  -i, --image IMAGE      Image name (default: default → claude-sandbox/default)
  -p, --projects DIR     Projects directory to mount (default: ~/projects)
```

### build.sh

```
Usage: build.sh [OPTIONS]

Options:
  -i, --image IMAGE      Image name (default: default → claude-sandbox/default)
```

### root-shell.sh / save-image.sh

```
Options:
  -n, --name NAME        Container name (default: claude-sandbox)
  -i, --image IMAGE      Image name (save-image.sh only)
```

## Multiple Environments

All images are prefixed with `claude-sandbox/` automatically:

```bash
# Build a project-specific image (creates claude-sandbox/myproject)
./build.sh -i myproject

# Run it
./run.sh -i myproject -n myproject -p ~/work/myproject

# In another terminal
./root-shell.sh -n myproject
./save-image.sh -n myproject -i myproject
```

## Managing Images

List all sandbox images:

```bash
podman images 'claude-sandbox/*'
```

Remove an image:

```bash
podman rmi claude-sandbox/myproject
```

Remove all sandbox images:

```bash
podman rmi $(podman images -q 'claude-sandbox/*')
```

## Included Tools

- Node.js, npm
- Python 3, pip
- Git, git-extras, git-filter-repo, gh (GitHub CLI)
- ripgrep, fd, vim

## Troubleshooting

### Permission denied on ~/.claude

The container uses `--userns=keep-id` to map your host UID. If you see permission errors, ensure the mounted directories are owned by your user.

### GCP credentials not found

Run `gcloud auth application-default login` on the host to create credentials at `~/.config/gcloud/application_default_credentials.json`.

### Slow container startup

First run may be slow due to Podman's user namespace setup. Subsequent runs are faster.
