# CLAUDE.md - comr Development Guide

Project-specific instructions for AI assistants working on the comr (Claude-Open MCP Router) flake.

## Project Overview

**comr** is a semantic MCP server router for Claude Code that provides:
- AI-driven server selection (semantic routing)
- Pre-configured workspaces (Director-like functionality)
- Agent-enhanced workspaces (specialized expertise)
- MCP server registry integration (auto-install npm/pip packages)

### Architecture

```
comr (Semantic Router)
  ├── Intent Analysis (gemini-2.0-flash-lite)
  ├── Server Selection (from servers.json + registry)
  ├── Config Transformation (flake → nix run, package → npx/uvx)
  └── Claude Execution (optimized server set)

Workspaces (Pre-configured)
  ├── python-dev, web-dev, data-analysis, devops, api-dev
  └── Agent-enhanced: security-audit, code-review, refactor, perf-optimize, accessibility-check

Registry (Auto-discovery)
  ├── npm/npx servers (11): github, postgres, sqlite, slack, etc.
  └── pip/uvx servers (2): aws, docker
```

## Technology Stack

- **Language:** Nix (flake-based)
- **Runtime:** Bash (writeShellScript)
- **Dependencies:** jq, claude-code, nix
- **MCP Protocol:** stdio (npm/npx/uvx packages + nix run flakes)
- **AI Integration:** Claude Code CLI

## File Structure

```
/home/lessuseless/Projects/Flakes/comr-flake/
├── flake.nix                    # Main flake definition
├── CLAUDE.md                    # This file (project instructions)
├── README.md                    # User-facing documentation
├── DIRECTOR_COMPARISON.md       # Director vs comr comparison
└── .git/                        # Git repository

/home/lessuseless/.config/comr/
├── servers.json                 # User's configured MCP servers
├── server-registry.json         # Auto-installable server registry
├── sync-registry.sh             # Registry sync tool
├── README.md                    # comr usage guide
├── REGISTRY.md                  # Registry documentation
├── WORKSPACES.md               # Workspace guide
├── AGENTS.md                   # Agent invocation guide
└── CONTINUATION.md             # Session continuation guide
```

## Development Guidelines

### Nix Flake Standards

1. **Use writeShellScript for apps**
   ```nix
   pkgs.writeShellScript "workspace-name" ''
     #!/usr/bin/env bash
     set -euo pipefail
     # Script content
   ''
   ```

2. **Hardcode Nix store paths**
   ```nix
   # Good
   ${pkgs.jq}/bin/jq
   ${pkgs.claude-code}/bin/claude

   # Bad
   jq  # Not in PATH
   ```

3. **Use builtins.toJSON for config generation**
   ```nix
   cat > "$CONFIG" <<'EOF'
   ${builtins.toJSON { mcpServers = servers; }}
   EOF
   ```

4. **Proper cleanup with traps**
   ```bash
   TEMP=$(mktemp)
   trap "rm -f '$TEMP'" EXIT
   ```

### Helper Functions

#### mkWorkspace (Regular Workspaces)

**Purpose:** Create workspace with MCP servers only

**Signature:**
```nix
mkWorkspace = name: servers: description: pkgs.writeShellScript "${name}-workspace" ''
  # Implementation
'';
```

**Usage:**
```nix
apps.x86_64-linux.python-dev = {
  type = "app";
  program = mkWorkspace "python-dev"
    {
      git = {command = "uvx"; args = ["mcp-server-git"];};
      sqlite = {command = "npx"; args = ["-y" "mcp-sqlite"];};
    }
    "Python development with SQLite";
};
```

#### mkWorkspaceWithAgent (Agent Workspaces)

**Purpose:** Create workspace with MCP servers + specialized agent

**Signature:**
```nix
mkWorkspaceWithAgent = name: servers: agent: description: pkgs.writeShellScript "${name}-agent-workspace" ''
  # Implementation with --agents flag
'';
```

**Usage:**
```nix
apps.x86_64-linux.security-audit = {
  type = "app";
  program = mkWorkspaceWithAgent "security-audit"
    {
      git = {command = "uvx"; args = ["mcp-server-git"];};
      filesystem = {command = "npx"; args = ["-y" "@modelcontextprotocol/server-filesystem"];};
    }
    {
      name = "security";
      description = "Security auditor";
      prompt = "You are a security auditor. Scan for OWASP Top 10...";
    }
    "Security audit workspace";
};
```

### Server Definition Format

All MCP servers use this structure:

```nix
{
  server-name = {
    command = "npx" | "uvx" | "nix";
    args = ["..." "..."];
    env = {
      ENV_VAR = "value";  # Optional
    };
  };
}
```

**Three server types:**

1. **npm/npx packages:**
   ```nix
   {
     github = {
       command = "npx";
       args = ["-y" "@modelcontextprotocol/server-github"];
     };
   }
   ```

2. **pip/uvx packages:**
   ```nix
   {
     aws = {
       command = "uvx";
       args = ["awslabs-mcp-server"];
     };
   }
   ```

3. **Nix flakes:**
   ```nix
   {
     playwright = {
       command = "nix";
       args = ["run" "github:modelcontextprotocol/servers/main#playwright" "--"];
     };
   }
   ```

## Adding New Features

### Adding a New Workspace

1. **Identify server requirements**
   - What MCP servers are needed?
   - Check `~/.config/comr/server-registry.json` for available servers
   - Check `~/.config/comr/servers.json` for configured servers

2. **Choose workspace type**
   - Regular workspace: `mkWorkspace`
   - Agent-enhanced: `mkWorkspaceWithAgent`

3. **Add to flake.nix apps section**
   ```nix
   apps.x86_64-linux.my-workspace = {
     type = "app";
     program = mkWorkspace "my-workspace"
       {
         git = {command = "uvx"; args = ["mcp-server-git"];};
         # ... other servers
       }
       "Description of workspace purpose";
   };
   ```

4. **Test the workspace**
   ```bash
   nix flake show
   nix run .#my-workspace "test task"
   ```

5. **Document in WORKSPACES.md**

### Adding a New Agent Workspace

1. **Define agent persona**
   ```nix
   {
     name = "agent-id";
     description = "Agent role";
     prompt = "Detailed instructions for agent behavior...";
   }
   ```

2. **Select appropriate servers**
   - Match servers to agent's needs
   - Example: Security agent needs filesystem, git
   - Example: Performance agent needs postgres, sqlite

3. **Add to flake.nix**
   ```nix
   apps.x86_64-linux.my-agent = {
     type = "app";
     program = mkWorkspaceWithAgent "my-agent"
       { /* servers */ }
       { /* agent definition */ }
       "Agent workspace description";
   };
   ```

4. **Document in AGENTS.md**

### Adding Servers to Registry

1. **Edit `~/.config/comr/sync-registry.sh`**
   ```bash
   NPM_SERVERS='[
     ...existing servers...,
     {
       "name": "new-server",
       "description": "What it does",
       "type": "package",
       "command": "npx",
       "args": ["-y", "@scope/package-name"],
       "source": "npm",
       "keywords": ["keyword1", "keyword2"]
     }
   ]'
   ```

2. **Run sync script**
   ```bash
   ~/.config/comr/sync-registry.sh
   ```

3. **Verify in registry**
   ```bash
   jq '.servers."new-server"' ~/.config/comr/server-registry.json
   ```

4. **Document in REGISTRY.md**

## Testing

### Manual Testing

```bash
# Test comr semantic routing
nix run . "what is the git status"

# Test regular workspace
nix run .#python-dev "analyze this script"

# Test agent workspace
nix run .#security-audit "scan for vulnerabilities"

# Test with continuation
nix run .#web-dev "test UI"
nix run .#web-dev -- --continue -p "verify fixes"

# Test zen-agents workspace (multi-model AI orchestration)
nix run .#zen-agents "analyze this codebase using multiple AI models"
nix run .#zen-agents "use consensus to decide on architecture approach"
nix run .#zen-agents "delegate this ML task to gemini CLI"
```

### Testing Zen-Agents Workspace

The `zen-agents` workspace provides access to multiple AI models and CLI agents through the Zen MCP server:

**Available Models:**
- Gemini (2.5-pro, 2.0-flash, 2.0-flash-lite) via GEMINI_API_KEY
- GPT-4, Claude, other models via OPENROUTER_API_KEY
- Local models via CLI delegation (gemini-cli, qwen-cli, codex-cli)

**Available Tools:**
- `chat` - Collaborative thinking with specific models
- `thinkdeep` - Multi-stage investigation and analysis
- `planner` - Sequential task planning
- `consensus` - Multi-model decision making through debate
- `codereview` - Systematic code review with expert validation
- `debug` - Root cause analysis
- `precommit` - Git change validation
- `clink` - Delegate to external CLI agents

**Example Usage:**

```bash
# Multi-model consensus on architecture decision
nix run .#zen-agents "Use consensus to decide: should we use microservices or monolith for this project?"

# Deep analysis with thinkdeep
nix run .#zen-agents "Use thinkdeep to investigate why our API is slow. Check database queries, algorithm complexity, and caching opportunities."

# Delegate to specific CLI agent
nix run .#zen-agents "Use clink with gemini CLI to generate ML training code for image classification"

# Code review with expert validation
nix run .#zen-agents "Use codereview to analyze security vulnerabilities in auth system"

# Planning complex migrations
nix run .#zen-agents "Use planner to create a step-by-step plan for migrating from REST to GraphQL"
```

**Environment Variables:**
- `GEMINI_API_KEY` - Automatically set from environment
- `OPENROUTER_API_KEY` - Automatically set from environment
- `DEFAULT_MODEL` - Set to "auto" for automatic model selection

### Verify Flake

```bash
# Check flake structure
nix flake check

# Show all apps
nix flake show

# Build specific app
nix build .#apps.x86_64-linux.python-dev
```

### Debug Issues

```bash
# Run with bash debug
bash -x $(nix build .#apps.x86_64-linux.comr --print-out-paths)/bin/comr "task"

# Check MCP server selection
CLAUDE_SETTINGS=/tmp/test.json nix run . "task"
cat /tmp/test.json | jq
```

## Code Standards

### Bash Scripts

```bash
#!/usr/bin/env bash
set -euo pipefail  # Always include

# Use descriptive variable names
WORKSPACE_CONFIG=$(mktemp)
SERVER_LIST="git,sequential-thinking,zen"

# Always cleanup temp files
trap "rm -f '$WORKSPACE_CONFIG'" EXIT

# Use jq for JSON operations
SERVERS=$(echo "$JSON" | jq -r '.servers[]')

# Echo to stderr for status messages
echo "🎯 Workspace: $NAME" >&2
```

### Nix Code

```nix
# Use let-in for complex logic
let
  commonServers = {
    git = {command = "uvx"; args = ["mcp-server-git"];};
    sequential-thinking = {command = "npx"; args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];};
  };
in
{
  apps.x86_64-linux = {
    workspace1 = mkWorkspace "workspace1" (commonServers // {extra = {...};}) "desc";
    workspace2 = mkWorkspace "workspace2" (commonServers // {other = {...};}) "desc";
  };
}

# Use inherit for cleaner code
{
  name = "security";
  description = "Security auditor";
  prompt = "...";
} // Use: { inherit (agent) description prompt; }
```

### Documentation

1. **Keep README.md user-focused**
   - Quick start
   - Common use cases
   - Troubleshooting

2. **Keep technical details in docs/**
   - REGISTRY.md for server registry
   - WORKSPACES.md for workspace usage
   - AGENTS.md for agent patterns
   - CONTINUATION.md for session management

3. **Update CLAUDE.md (this file) for developers**
   - Architecture changes
   - New patterns
   - Development guidelines

## Common Tasks

### Update Intent Analysis Prompt

Location: `flake.nix` lines ~100-120

```nix
INTENT_ANALYSIS=$(cat <<EOF | ${pkgs.claude-code}/bin/claude -p --model "gemini-2.0-flash-lite" --output-format json --allowedTools ""
Analyze this task and determine which MCP servers are needed.

Available MCP servers:
$AVAILABLE_SERVERS

Rules:
1. ALWAYS include "git" and "sequential-thinking" as baseline
2. Add specialized servers ONLY if task explicitly needs them
3. Minimize server count for token efficiency
...
EOF
)
```

### Change Default Model for Intent Analysis

```nix
# Current: gemini-2.0-flash-lite
${pkgs.claude-code}/bin/claude -p --model "gemini-2.0-flash-lite"

# To change:
${pkgs.claude-code}/bin/claude -p --model "claude-3-haiku"
```

### Add Environment Variables to Workspace

```nix
mkWorkspace "workspace-with-env"
  {
    github = {
      command = "npx";
      args = ["-y" "@modelcontextprotocol/server-github"];
      env = {
        GITHUB_TOKEN = "$GITHUB_TOKEN";  # From environment
      };
    };
  }
  "GitHub workspace with auth";
```

### Modify PID Cleanup Logic

Location: `flake.nix` lines ~49-62

```bash
cleanup() {
  if [[ -n "$CLAUDE_PID" ]]; then
    # Send TERM signal to Claude Code process group
    kill -TERM -"$CLAUDE_PID" 2>/dev/null || true
    # Wait briefly for graceful shutdown
    sleep 0.5
    # Force kill if still running
    kill -KILL -"$CLAUDE_PID" 2>/dev/null || true
  fi
  rm -f "$TEMP_CONFIG"
}
trap cleanup EXIT INT TERM
```

## Performance Optimization

### Token Usage Targets

- **Semantic routing (comr):** 1,000-1,500 tokens (optimal)
- **Regular workspace:** 2,000-3,000 tokens (fixed)
- **Agent workspace:** 2,500-3,500 tokens (fixed + agent)

### Minimize Server Count

```nix
# Good: Only essential servers
{
  git = {...};
  sequential-thinking = {...};
  postgres = {...};  # Needed for task
}

# Bad: Kitchen sink approach
{
  git = {...};
  sequential-thinking = {...};
  github = {...};      # Not needed
  slack = {...};       # Not needed
  stripe = {...};      # Not needed
}
```

### Intent Analysis Optimization

```bash
# Use cheapest model for intent analysis
--model "gemini-2.0-flash-lite"  # Fast, cheap

# Provide clear intent prompt with keywords
"Available MCP servers:
- git: Version control (keywords: commit, push, diff)
- postgres: Database (keywords: query, table, sql)"
```

## Troubleshooting

### Issue: Workspace not found

```bash
# List all apps
nix flake show

# Check app exists
nix eval .#apps.x86_64-linux --apply builtins.attrNames
```

### Issue: Server install fails

```bash
# Test server manually
npx -y @modelcontextprotocol/server-postgres
uvx awslabs-mcp-server

# Check dependencies
which npx node
which uvx python
```

### Issue: Config transformation fails

```bash
# Debug jq transformation
jq --arg servers "git,zen" '
  .mcpServers |
  with_entries(select(.key | IN($servers | split(",")[])))
' ~/.config/comr/servers.json

# Check for syntax errors
jq '.' ~/.config/comr/servers.json
```

### Issue: Agent not applying

```bash
# Verify agent flag
claude --agents '{"test": {"description": "Test", "prompt": "You are a test agent"}}' -p "hello"

# Check agent definition in workspace
nix eval .#apps.x86_64-linux.security-audit.program --raw | grep -A 5 "agents"
```

## Git Workflow

### Branch Strategy

- `main` - Stable releases
- `develop` - Active development
- `feature/*` - New features
- `fix/*` - Bug fixes

### Commit Messages

```
feat: add ML optimization workspace
fix: correct agent prompt for security audit
docs: update WORKSPACES.md with new examples
refactor: extract server transformation logic
perf: optimize intent analysis prompt
```

### Before Committing

```bash
# Format Nix code
nixpkgs-fmt flake.nix

# Check flake
nix flake check

# Test key workspaces
nix run .#python-dev "test"
nix run .#security-audit "test"

# Update lock file
nix flake update
```

## Integration Points

### System Flake Integration

```nix
# ~/Projects/Flakes/nixos-config-with-mcp/flake.nix
{
  inputs.comr = {
    url = "path:/home/lessuseless/Projects/Flakes/comr-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Add comr package
  home.packages = [
    inputs.comr.packages.${pkgs.system}.default
  ];

  # Or add workspace command
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "workspace" ''
      nix run ${inputs.comr}#"$@"
    '')
  ];
}
```

### Claude Settings Integration

comr sets `CLAUDE_SETTINGS` environment variable:

```bash
CLAUDE_SETTINGS="$TEMP_CONFIG" claude -p "$@"
```

This overrides `~/.claude/settings.json` for the session.

### MCP Registry Integration

comr loads servers from two sources:

1. **Configured:** `~/.config/comr/servers.json` (priority)
2. **Registry:** `~/.config/comr/server-registry.json` (fallback)

Merged via jq in step 3 of transformation.

## Future Enhancements

### Planned Features

- [ ] Automatic registry sync on startup
- [ ] Server capability detection (tools/resources/prompts)
- [ ] Usage analytics (track server selection patterns)
- [ ] Smart caching (keep frequently-used servers warm)
- [ ] Workspace templates (generate custom workspaces)
- [ ] Remote registry support (private/company registries)

### Enhancement Ideas

1. **Workspace Composition**
   ```nix
   # Combine workspaces
   apps.x86_64-linux.full-stack = mkWorkspace "full-stack"
     (python-dev.servers // web-dev.servers)
     "Full-stack development";
   ```

2. **Dynamic Server Selection**
   ```nix
   # Conditional servers based on environment
   mkWorkspace "adaptive"
     (baseServers // lib.optionalAttrs (hasDocker) {
       docker = {...};
     })
     "Adaptive workspace";
   ```

3. **Multi-Agent Workflows**
   ```nix
   # Sequential agent pipeline
   apps.x86_64-linux.full-audit = mkMultiAgentWorkspace
     [security-agent perf-agent quality-agent]
     "Complete codebase audit";
   ```

## Contact & Contribution

- **Issues:** File in GitHub issues
- **PRs:** Submit to `develop` branch
- **Docs:** Update relevant .md files
- **Tests:** Include test cases for new features

## Quick Reference

### Build & Run

```bash
# Build comr
nix build

# Run comr
nix run . "task"

# Run workspace
nix run .#workspace-name "task"

# Show all apps
nix flake show
```

### Common Paths

- Flake: `~/Projects/Flakes/comr-flake/flake.nix`
- Config: `~/.config/comr/servers.json`
- Registry: `~/.config/comr/server-registry.json`
- Docs: `~/.config/comr/*.md`

### Key Commands

```bash
# Semantic routing
comr "task"

# Workspace
nix run .#python-dev "task"

# Agent workspace
nix run .#security-audit "task"

# Zen multi-model workspace
nix run .#zen-agents "use consensus for architecture decision"
nix run .#zen-agents "use thinkdeep to debug performance issue"

# Continue session
nix run .#workspace -- --continue -p "task"

# Update registry
~/.config/comr/sync-registry.sh
```

---

**Remember:** comr is about **optimal MCP server selection** through three approaches:
1. **Semantic** - AI-driven (optimal tokens)
2. **Workspace** - Pre-configured (consistent)
3. **Agent** - Expert persona (specialized)

All with Nix's cryptographic guarantees! 🚀
