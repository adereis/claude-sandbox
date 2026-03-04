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

# Inside the container, start Claude (see Permission Modes below)
claude
```

## Permission Modes

Claude Code has several permission modes, from most to least restrictive:

### Default Mode (Recommended for Most Users)

```bash
claude
```

Claude prompts for confirmation on potentially dangerous operations. You approve each action as it runs.

### Pre-approved Tools

Allow specific tools without prompting, while still requiring approval for others:

```bash
# Allow file operations, prompt for bash commands
claude --allowedTools "Read,Write,Edit,Glob,Grep"

# Allow git commands, prompt for everything else
claude --allowedTools "Bash(git:*)"
```

### Block Specific Tools

Deny tools you consider risky:

```bash
# Block network tools (note: incomplete, many ways to access network)
claude --disallowedTools "Bash(curl:*),Bash(wget:*),WebFetch,WebSearch"
```

### Full Autonomy

Skip all permission checks. Use only when you accept the risks:

```bash
claude --dangerously-skip-permissions
```

### Combining Options

```bash
# Allow most tools, but block network access from bash
claude --allowedTools "Read,Write,Edit,Glob,Grep,Bash(git:*)" \
       --disallowedTools "Bash(curl:*),Bash(wget:*),WebFetch"
```

**Note**: Network access is filtered by default — only domains required by Claude Code are reachable. See [Network Restrictions](#network-restrictions) for details.

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

## Network Restrictions

Outbound network access is filtered by default through a tinyproxy whitelist proxy. Only domains required for Claude Code are reachable:

- `api.anthropic.com` — Claude API
- `claude.ai`, `platform.claude.com` — Authentication
- `github.com`, `api.github.com` — GitHub integration
- `registry.npmjs.org` — npm packages
- `statsig.anthropic.com`, `sentry.io` — Telemetry

Cloud provider domains (Vertex AI, Bedrock) are auto-detected from environment variables and credentials.

### Allowing extra domains

For one-off additions:

```bash
./run.sh --network-allow jira.example.com --network-allow registry.internal.com
```

For a reusable whitelist file (ERE patterns, one per line):

```bash
echo '(^|\.)mycompany\.atlassian\.net$' > ~/my-domains.conf
./run.sh --network-whitelist ~/my-domains.conf
```

### Disabling network restrictions

```bash
./run.sh --network-unrestricted
```

### Limitations

- Only filters HTTP/HTTPS traffic (raw TCP/SSH connections are not filtered)
- Applications must respect proxy environment variables (all included tools do)
- DNS resolution is unrestricted (but connections to non-whitelisted domains are blocked)

## Scripts

All scripts support `-h` or `--help` for usage information.

### run.sh

```
Usage: run.sh [OPTIONS] [-- COMMAND]

Options:
  -n, --name NAME              Container name (default: claude-sandbox)
  -i, --image IMAGE            Image name (default: default → claude-sandbox/default)
  -p, --projects DIR           Projects directory to mount (default: ~/projects)
  --network-unrestricted       Disable network filtering
  --network-whitelist FILE     Additional network domain whitelist file
  --network-allow DOMAIN       Allow an extra network domain (repeatable)
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

### General
- Git, git-extras, git-filter-repo, gh (GitHub CLI)
- ripgrep, fd, vim

### Languages & Runtimes
- Node.js, npm
- Python 3, pip

### C/C++ Development
- **Compilers**: gcc, g++, clang
- **Build systems**: cmake, make, ninja, autoconf/automake, meson, pkg-config
- **Debugging**: gdb, valgrind, strace, ltrace, perf
- **Static analysis**: clang-tidy, clang-format, cppcheck, bear
- **Sanitizers**: AddressSanitizer, UBSan, ThreadSanitizer, LeakSanitizer
- **Libraries**: libpcap-devel, openssl-devel, zlib-devel, cmocka

## Security Considerations

This setup provides **convenience isolation**, not **security hardening**. It protects against accidents, not malicious behavior.

### What's Protected

| Threat | Status |
|--------|--------|
| Accidents outside ~/projects | Protected — can't touch other home directories |
| System file modification | Protected — rootless Podman, container root ≠ host root |
| Persistent malware | Mitigated — `--rm` clears container on exit |
| Other users' files | Protected — namespace isolation |

### What's Exposed

| Asset | Access | Risk |
|-------|--------|------|
| `~/projects` | Read-write | Full modification/deletion of all projects |
| `~/.claude` | Read-write | Auth tokens, conversation history |
| `~/.config/gcloud` | Read-only | Can authenticate to GCP, access cloud resources |
| Network | Filtered (whitelist proxy) | Bypass with `--network-unrestricted`; HTTP/HTTPS only |
| CPU/Memory | Unlimited | Could DoS host |

### With `--dangerously-skip-permissions`

Claude can, without confirmation:
- Delete or modify your entire projects directory
- Read and exfiltrate source code over the network
- Use your cloud credentials to access resources
- Install and run arbitrary software

### Bottom Line

This setup is for **containing mess, not containing malice**. It's appropriate for experimentation where you trust the model but want easy cleanup and separation from the rest of your system.

## Troubleshooting

### Permission denied on ~/.claude

The container uses `--userns=keep-id` to map your host UID. If you see permission errors, ensure the mounted directories are owned by your user.

### GCP credentials not found

Run `gcloud auth application-default login` on the host to create credentials at `~/.config/gcloud/application_default_credentials.json`.

### Slow container startup

First run may be slow due to Podman's user namespace setup. Subsequent runs are faster.
