# Migration Guide: comr-flake → claude-code-nix-std

This guide helps you migrate from the monolithic `comr-flake` to the modular `claude-code-nix-std` architecture.

## Quick Start

### What Changed?

**Before:**
- Single `flake.nix` file (1115 lines)
- Inline workspace definitions
- Manual MCP server configuration

**After:**
- Modular cells (13 cells, ~100 lines each)
- Composable workspaces
- Automatic MCP server discovery
- Multi-agent orchestration
- Comprehensive observability

### Architecture Overview

```
claude-code-nix-std/
├── flake.nix                    # Root flake with std.growOn
└── cells/                       # Modular components
    ├── llm/                     # Universal LLM interface
    ├── config/                  # Configuration management
    ├── diagnostics/             # Observability & monitoring
    ├── mcp/                     # MCP server registry (100+ servers)
    ├── agents/
    │   ├── claude-code/         # Claude Code agent
    │   ├── gemini-cli/          # Gemini CLI with 70+ extensions
    │   └── qwen/                # Qwen-Agent framework
    ├── routing/                 # Semantic server selection
    ├── workspaces/              # Workspace composition
    ├── orchestrators/           # Multi-agent coordination
    ├── prompts/                 # DSPy prompt optimization
    ├── marketplaces/            # Plugin discovery
    └── examples/                # User extensibility templates
```

## Migration Steps

### 1. Install New Flake

```bash
# Clone or checkout the new architecture
cd ~/Projects/Flakes/claude-code-nix-std

# Build to ensure everything works
nix flake show
nix build
```

### 2. Migrate API Keys

**Old way (environment variables):**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
```

**New way (managed by config cell):**
```bash
# Option 1: Environment variables (still works)
export ANTHROPIC_API_KEY="sk-ant-..."

# Option 2: System keyring (recommended)
nix run .#config.runnables.set-key -- anthropic keyring

# Option 3: Age-encrypted secrets
nix run .#config.runnables.set-key -- anthropic age-encrypted

# View configuration
nix run .#config.runnables.show
```

### 3. Migrate Workspaces

**Old commands (still work):**
```bash
nix run .#python-dev "implement feature"
nix run .#security-audit "scan for vulnerabilities"
```

**New features:**
```bash
# Session continuation
nix run .#python-dev "implement authentication"
nix run .#python-dev -- --continue "add tests for auth"

# Multi-agent orchestration
nix run .#orchestrators.langgraph-security-audit "audit codebase"

# Cost tracking
nix run .#diagnostics.runnables.cost-report
```

### 4. Create Custom Workspaces

**Old way (modify flake.nix):**
```nix
# Add to flake.nix apps section
apps.x86_64-linux.my-workspace = mkWorkspace "my-workspace" {...};
```

**New way (user extensibility):**
```nix
# cells/examples/custom-workspaces.nix
{inputs, cell}: {
  my-workspace = inputs.cells.workspaces.lib.compose {
    agents = ["claude-code"];
    servers = ["git" "postgres" "my-custom-server"];
    prompts = ["code-review"];
  };
}

# Usage:
# nix run .#examples.custom-workspaces.my-workspace -- "task"
```

### 5. Enable Observability (New Feature)

```bash
# Real-time logs
nix run .#diagnostics.runnables.tail-logs

# Cost report
nix run .#diagnostics.runnables.cost-report

# Performance metrics
nix run .#diagnostics.runnables.perf-report

# Health check
nix run .#diagnostics.runnables.health-check

# Start Grafana dashboards
nix run .#diagnostics.runnables.grafana
```

### 6. Use Multi-Agent Orchestration (New Feature)

```bash
# LangGraph: State machine workflow
nix run .#orchestrators.langgraph-security-audit "audit authentication system"

# CrewAI: Role-based team
nix run .#orchestrators.crewai-code-review "review PR #123"

# AutoGen: Conversational agents
nix run .#orchestrators.autogen-discussion "discuss microservices vs monolith"
```

### 7. Optimize Prompts with DSPy (New Feature)

```bash
# Use pre-optimized prompts
nix eval '.#prompts.lib.use "security-audit" {...}'

# Optimize custom prompt
nix run .#prompts.runnables.optimize-security-audit
```

## Backward Compatibility

All existing `comr-flake` commands continue to work:

```bash
# Semantic routing (comr)
nix run . "what is the git status"

# Workspaces
nix run .#python-dev "analyze this script"

# Agent workspaces
nix run .#security-audit "scan for vulnerabilities"
```

## Migration Checklist

- [ ] Clone/checkout `claude-code-nix-std`
- [ ] Run `nix flake show` to verify structure
- [ ] Set up API keys using config cell
- [ ] Test existing workspaces still work
- [ ] Migrate custom MCP servers (if any)
- [ ] Create custom workspaces in `cells/examples/` (if needed)
- [ ] Enable diagnostics and monitoring
- [ ] Review cost reports and set limits
- [ ] Explore multi-agent orchestration patterns
- [ ] Try DSPy prompt optimization
- [ ] Use session continuation for long tasks

## Common Issues

### Issue 1: "Server not found"

**Problem:** Old server name doesn't match registry.

**Solution:**
```bash
# Search registry for server
nix eval .#mcp.lib.searchServers '"postgres"'
```

### Issue 2: "API key not set"

**Problem:** Missing API key configuration.

**Solution:**
```bash
# Set API key via config cell
nix run .#config.runnables.set-key -- anthropic environment

# Or export environment variable
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Issue 3: "Workspace behavior changed"

**Problem:** Workspace definition differs from old version.

**Solution:**
```bash
# Check new workspace definition
nix eval .#agents.claude-code.data.workspaces.python-dev

# Or use old workspace structure
nix eval .#examples.legacy-workspaces.python-dev
```

## Getting Help

```bash
# Show all available commands
nix flake show

# Show workspace servers
nix eval .#agents.claude-code.data.workspaces.python-dev.servers

# Show MCP registry
nix eval .#mcp.data.servers --apply 'builtins.attrNames'

# System health check
nix run .#diagnostics.runnables.health-check
```

## Detailed Migration Guide

For comprehensive migration instructions, examples, and templates, see:

**[cells/examples/CLAUDE.md](cells/examples/CLAUDE.md) - Migration Guide Section**

This includes:
- 11-step detailed migration process
- Architecture comparison
- 5 example templates for custom workspaces/orchestrators
- Common migration issues with solutions
- Performance comparison
- User extensibility patterns

## New Features Highlights

### 1. Configuration Management
- Centralized API key management
- Environment profiles (dev/staging/prod)
- Cost caps and rate limits
- Secrets management (keyring, age-encrypted)

### 2. Observability
- Structured JSON logging
- Prometheus metrics
- Distributed tracing (OpenTelemetry)
- 5 pre-configured Grafana dashboards
- Real-time cost tracking

### 3. Multi-Agent Orchestration
- LangGraph (state machines)
- CrewAI (role-based teams)
- AutoGen (conversational)

### 4. Performance Optimization
- Response caching (semantic + exact match)
- Request batching
- Token optimization
- Cost-aware model selection
- Rate limiting with exponential backoff

### 5. Workspace Lifecycle
- Session continuation
- State persistence
- Checkpoint/restore
- Resource tracking and cleanup

### 6. DSPy Prompt Optimization
- Automatic prompt improvement
- 20+ pre-optimized prompts
- Training data workflow
- Benchmark comparison

### 7. Extended MCP Registry
- 100+ MCP servers
- Auto-sync from upstream
- Version management
- Compatibility testing

### 8. Nushell Integration (New)
- **Rich Data Display**: All diagnostic and management tools now use Nushell for beautiful table formatting
- **Native JSON Handling**: No more jq pipelines - structured data is first-class
- **Statistics & Aggregation**: Built-in functions for percentiles, group-by, and complex filtering
- **Better Error Handling**: try/catch instead of bash error checking
- **Clean Syntax**: Data transformations are readable pipelines

**Nushell-powered Commands:**

```bash
# Config Management
comr config show                          # Beautiful config display with tables
comr config cost-report --period week     # Aggregate costs with group-by
comr config list-keys                     # API key status with validation
comr config compare-profiles dev prod     # Side-by-side profile comparison

# Diagnostics
comr-logs --level error --workspace python-dev  # Multi-criteria log filtering
comr-cost-report --period week --group-by model # Cost aggregation
comr-perf-report --since 1hour                  # Latency percentiles (p50/p95/p99)

# MCP Registry
comr mcp search postgres --capability database  # Rich search with filtering
comr mcp list --ecosystem claude-code           # Filtered server listing
comr mcp sync-registry --source npm             # Fetch and merge registries
comr mcp check-updates                          # Version checking against npm/PyPI
comr mcp stats                                  # Registry statistics

# Workspace Sessions
comr sessions --workspace python-dev --since 3day  # Session listing with filters
comr session show 2025-01-15-abc123                # Detailed session inspection
comr session-stats --period week                   # Aggregate session statistics
comr session compare sess1 sess2                   # Side-by-side comparison

# Orchestrators
# 4 production-ready Nushell workflow examples:
# - langgraph-security-audit.nu (Sequential Pipeline)
# - mapreduce-codebase.nu (Parallel Analysis)
# - consensus-architecture.nu (Multi-Model Validation)
# - crewai-code-review.nu (Hierarchical Delegation)
```

**Example Output (Before vs After):**

**Before (bash + jq):**
```bash
$ jq '.' ~/.config/comr/config.json
{
  "version": "1.0.0",
  "activeProfile": "dev",
  "profiles": { ... }
}
```

**After (Nushell):**
```bash
$ comr config show
📋 Configuration Overview
=========================

Active Profile: dev

User Preferences:
  defaultModel: claude-3.5-sonnet
  temperature: 0.7
  maxTokens: 4096

API Keys Status:
╭───────────┬─────────╮
│ provider  │ status  │
├───────────┼─────────┤
│ anthropic │ ✅ Set  │
│ google    │ ✅ Set  │
│ openai    │ ❌ Not Set│
╰───────────┴─────────╯
```

**Benefits:**
- **Readability**: Formatted tables instead of raw JSON
- **Filtering**: Complex multi-field filters without grep chains
- **Aggregation**: Native group-by, sum, avg without awk
- **Type Safety**: Null checking built-in
- **Error Handling**: Clean try/catch blocks

**When We Use Bash vs Nushell:**

**Nushell is used for:**
- ✅ Data display and formatting
- ✅ JSON parsing and transformation
- ✅ Filtering and searching
- ✅ Statistics and aggregation
- ✅ Table formatting

**Bash is kept for:**
- ✅ Simple file operations (mkdir, cp, mv)
- ✅ Process management (kill, ps)
- ✅ Interactive prompts (read -s)
- ✅ External tool orchestration
- ✅ Integration with nix eval

**All bash scripts are validated with ShellCheck** to catch common bugs:
- ✅ Quoting issues (SC2086, SC2046)
- ✅ Variable expansion bugs (SC2154)
- ✅ Missing `set -euo pipefail`
- ✅ Unsafe temp file handling
- ✅ Array vs string confusion

This hybrid approach gives us the best of both worlds: Nix for build-time reproducibility, Nushell for runtime data operations, bash for system operations, and **ShellCheck** for bash script safety.

## Performance Comparison

| Metric | Old (comr-flake) | New (claude-code-nix-std) |
|--------|------------------|---------------------------|
| Token usage (semantic routing) | 1,000-1,500 | 1,000-1,500 (same) |
| Workspace startup | Fast | Fast (same) |
| Multi-agent support | No | Yes (new) |
| Cost tracking | Manual | Automatic (new) |
| Session continuation | No | Yes (new) |
| Prompt optimization | No | Yes (DSPy, new) |
| Observability | Minimal | Comprehensive (new) |
| Custom workspaces | Modify core | User extensions (new) |

## Support

- **Issues:** File in GitHub issues
- **Documentation:** See `cells/*/CLAUDE.md` files
- **Examples:** See `cells/examples/` directory

---

**Note:** The new architecture is fully backward compatible. You can migrate gradually while continuing to use existing workspaces.
