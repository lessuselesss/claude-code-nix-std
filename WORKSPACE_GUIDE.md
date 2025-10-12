# Workspace Configuration & Usage Guide

## Overview

Workspaces in comr-flake solve the **context explosion problem** by loading only the MCP servers you need for specific tasks. Instead of loading 80+ tools consuming 70k tokens, workspaces load 3-5 carefully selected servers consuming 2-5k tokens.

## Three Workspace Types

### 1. **Semantic Routing (comr)**
AI automatically selects MCP servers based on your task intent.

**When to use:**
- General development tasks
- Exploratory work
- When you're not sure which servers you need

**Token cost:** 1-3k tokens (minimal)

**Example:**
```bash
nix run ~/Projects/Flakes/comr-flake "commit my changes"
# AI selects: git, sequential-thinking

nix run ~/Projects/Flakes/comr-flake "review this code for security issues"
# AI selects: git, sequential-thinking, filesystem
```

### 2. **Pre-configured Workspaces**
Fixed server combinations optimized for specific workflows.

**When to use:**
- Repetitive tasks in a known domain
- Consistent environment needed
- Maximum token efficiency

**Token cost:** 2-4k tokens (fixed)

**Available workspaces:**
- `python-dev` - Python with SQLite + filesystem
- `web-dev` - Web dev with Playwright + GitHub + Brave Search
- `data-analysis` - PostgreSQL + SQLite + filesystem
- `devops` - Docker + AWS + GitHub
- `api-dev` - PostgreSQL + Slack + Stripe

**Example:**
```bash
nix run ~/Projects/Flakes/comr-flake#python-dev "analyze this script"
nix run ~/Projects/Flakes/comr-flake#web-dev "test the login flow"
```

### 3. **Agent-Enhanced Workspaces**
Pre-configured servers + specialized AI agent persona.

**When to use:**
- Expert analysis needed (security, performance, accessibility)
- Consistent methodology required
- Domain-specific expertise

**Token cost:** 2.5-5k tokens (fixed + agent)

**Available agent workspaces:**
- `security-audit` - OWASP Top 10 scanner
- `code-review` - Senior reviewer persona
- `refactor` - Code smell detector
- `perf-optimize` - Performance analysis
- `accessibility-check` - WCAG 2.1 AA compliance
- `baml-extract` - Type-safe data extraction
- `hackernews` - HN frontpage curator
- `agent-gateway` - A2A orchestration specialist

**Example:**
```bash
nix run ~/Projects/Flakes/comr-flake#security-audit "scan this codebase"
nix run ~/Projects/Flakes/comr-flake#perf-optimize "find slow queries"
```

## Optimal Usage Patterns

### Strategy 1: Start Minimal, Scale Up

```bash
# Start with semantic routing (cheapest)
nix run ~/Projects/Flakes/comr-flake "what does this function do"

# If you find yourself doing repeated Python work, switch to workspace
nix run ~/Projects/Flakes/comr-flake#python-dev "refactor this module"

# For deep analysis, use agent workspace
nix run ~/Projects/Flakes/comr-flake#security-audit "full security scan"
```

### Strategy 2: Match Task to Workspace

| Task Type | Best Workspace | Why |
|-----------|----------------|-----|
| Quick git operations | `comr` | Minimal overhead |
| Python development | `python-dev` | Fixed SQLite + filesystem |
| Web UI testing | `web-dev` | Playwright ready |
| Database optimization | `data-analysis` | Postgres + SQLite tools |
| Cloud infrastructure | `devops` | Docker + AWS integrated |
| API integration | `api-dev` | Database + 3rd party services |
| Security review | `security-audit` | OWASP-focused agent |
| Code quality | `code-review` | Senior reviewer persona |
| Performance issues | `perf-optimize` | Database + optimization focus |
| A11y compliance | `accessibility-check` | WCAG testing with Playwright |
| Data extraction | `baml-extract` | Type-safe parsing |
| News/research | `hackernews` | Web search optimized |

### Strategy 3: Session Continuation

Workspaces maintain conversation context across invocations:

```bash
# First session
nix run ~/Projects/Flakes/comr-flake#security-audit "scan auth module"
# Agent: "Found 3 SQL injection risks..."

# Continue in same workspace
nix run ~/Projects/Flakes/comr-flake#security-audit "show me the most critical one"
# Agent: "The login endpoint at auth.rs:45..."

# Different workspace breaks context
nix run ~/Projects/Flakes/comr-flake#code-review "what were those issues?"
# Agent: "I don't have context about previous issues"
```

**Rule:** Keep related work in the same workspace for context continuity.

## Creating Custom Workspaces

### Minimal Workspace Template

```nix
# Add to flake.nix apps.${system}
my-workspace = {
  type = "app";
  program = mkWorkspace "my-workspace"
    {
      git = {
        command = "uvx";
        args = ["mcp-server-git"];
      };
      sequential-thinking = {
        command = "npx";
        args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
      };
      # Add your specialized servers here
      postgres = {
        command = "npx";
        args = ["-y" "@modelcontextprotocol/server-postgres"];
      };
    }
    "My custom workspace description";
};
```

### Agent Workspace Template

```nix
my-agent-workspace = {
  type = "app";
  program = mkWorkspaceWithAgent "my-agent-workspace"
    {
      # Servers needed for this agent
      git = {
        command = "uvx";
        args = ["mcp-server-git"];
      };
      filesystem = {
        command = "npx";
        args = ["-y" "@modelcontextprotocol/server-filesystem"];
      };
    }
    {
      name = "my-agent-id";
      description = "Agent display name";
      prompt = "You are a specialist in X. Your responsibilities: 1) ..., 2) ..., 3) ...";
    }
    "Agent workspace description";
};
```

### Design Principles for Custom Workspaces

**1. Minimize Server Count**
- Start with: `git` + `sequential-thinking` (baseline)
- Add only what's essential for the workflow
- Each server adds ~500-2000 tokens

**2. Group Related Servers**
- Database workspace: `postgres` + `sqlite`
- Web workspace: `playwright` + `github` + `brave-search`
- Cloud workspace: `docker` + `aws`

**3. Agent Design**
- Clear, specific responsibilities
- Concrete methodology (numbered steps)
- Domain expertise in prompt
- Examples: "You are a security auditor. Check for: 1) SQL injection..."

**4. Avoid Duplication**
- Don't create `web-dev-2` if `web-dev` exists
- Extend existing workspaces instead
- Use semantic routing for one-off needs

## Workspace Selection Decision Tree

```
Are you doing repetitive work in a known domain?
├─ Yes → Use pre-configured workspace (python-dev, web-dev, etc.)
└─ No
    └─ Do you need expert analysis?
        ├─ Yes → Use agent workspace (security-audit, code-review, etc.)
        └─ No → Use semantic routing (comr)
```

## Performance Comparison

| Approach | Token Usage | Startup Time | Best For |
|----------|-------------|--------------|----------|
| Default Claude Code (~/.claude.json) | 70k tokens | ~3s | Full feature set |
| Semantic Routing (comr) | 1-3k tokens | ~1s | General tasks |
| Pre-configured Workspace | 2-4k tokens | <1s | Repetitive workflows |
| Agent Workspace | 2.5-5k tokens | <1s | Expert analysis |

**Token savings:** 14-35x reduction compared to loading all servers.

## Common Workflows

### Daily Development

```bash
# Morning: Check project status
nix run ~/Projects/Flakes/comr-flake "git status and recent commits"

# Development: Python work
nix run ~/Projects/Flakes/comr-flake#python-dev "implement user authentication"

# Testing: UI verification
nix run ~/Projects/Flakes/comr-flake#web-dev "test signup flow in browser"

# Pre-commit: Security check
nix run ~/Projects/Flakes/comr-flake#security-audit "scan for vulnerabilities"

# Code review: Get feedback
nix run ~/Projects/Flakes/comr-flake#code-review "review my changes"
```

### Data Pipeline Development

```bash
# Design phase
nix run ~/Projects/Flakes/comr-flake#data-analysis "design ETL schema"

# Implementation
nix run ~/Projects/Flakes/comr-flake#data-analysis "implement data transformations"

# Optimization
nix run ~/Projects/Flakes/comr-flake#perf-optimize "find slow queries"

# Deployment
nix run ~/Projects/Flakes/comr-flake#devops "deploy to AWS"
```

### API Integration

```bash
# Development
nix run ~/Projects/Flakes/comr-flake#api-dev "integrate Stripe payments"

# Testing
nix run ~/Projects/Flakes/comr-flake#api-dev "test webhook handlers"

# Monitoring
nix run ~/Projects/Flakes/comr-flake#api-dev "setup Slack notifications"
```

## Troubleshooting

### Workspace Not Found

```bash
# List all workspaces
nix flake show ~/Projects/Flakes/comr-flake

# Check specific workspace exists
nix eval ~/Projects/Flakes/comr-flake#apps.x86_64-linux --apply builtins.attrNames
```

### Server Install Fails

```bash
# Test server manually
npx -y @modelcontextprotocol/server-github
uvx mcp-server-git

# Check dependencies
which npx node npm
which uvx python3
```

### Wrong Servers Loaded (Semantic Routing)

The AI intent analysis might select suboptimal servers. Solutions:

1. **Use specific workspace instead:**
   ```bash
   # Instead of: comr "work with database"
   nix run ~/Projects/Flakes/comr-flake#data-analysis "work with database"
   ```

2. **Make task more explicit:**
   ```bash
   # Vague: "check the code"
   # Specific: "run git diff and review for SQL injection"
   ```

3. **Create custom workspace for frequent pattern**

## Advanced: Workspace Composition

Combine multiple workspace server sets:

```nix
# Create a "full-stack" workspace
full-stack = {
  type = "app";
  program = mkWorkspace "full-stack"
    (
      # Merge python-dev and web-dev servers
      python-dev-servers // web-dev-servers // {
        postgres = {...};  # Add additional server
      }
    )
    "Full-stack development environment";
};
```

## Best Practices

1. **Start your day with semantic routing** - Let AI learn your workflow
2. **Switch to workspace when pattern emerges** - 3+ similar tasks = workspace
3. **Use agent workspaces for deep analysis** - Security, performance, accessibility
4. **Keep sessions in same workspace** - Maintains conversation context
5. **Create custom workspaces sparingly** - Only for truly unique needs
6. **Review workspace usage weekly** - Optimize based on actual patterns

## Quick Reference

```bash
# Semantic routing
nix run ~/Projects/Flakes/comr-flake "TASK"

# Pre-configured workspace
nix run ~/Projects/Flakes/comr-flake#WORKSPACE "TASK"

# Agent workspace
nix run ~/Projects/Flakes/comr-flake#AGENT "TASK"

# List all workspaces
nix flake show ~/Projects/Flakes/comr-flake

# Test workspace
nix run ~/Projects/Flakes/comr-flake#python-dev "hello world"
```

## Next Steps

1. **Try semantic routing first** - Get familiar with AI server selection
2. **Identify your top 3 workflows** - Match them to existing workspaces
3. **Test agent workspaces** - See how specialized personas improve output
4. **Monitor token usage** - Use `/context` to track savings
5. **Create custom workspace** - Only if no existing workspace fits

**Remember:** The goal is **optimal token usage** while maintaining full capability. Use the lightest workspace that gets the job done.
