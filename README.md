# comr-flake

**Claude Orchestrated Workspaces with Semantic MCP Routing to reduce token usage** - Nix flake for workspace-based MCP server management with AI agent specialization.

## Problem

Loading all MCP servers consumes **70k tokens (35%)** of Claude Code's context window before you even start working. This leaves minimal space for actual code and conversation.

## Solution

**comr-flake** provides three approaches to dramatically reduce token usage:

1. **Semantic Routing (1-3k tokens)** - AI selects servers based on task intent
2. **Pre-configured Workspaces (2-4k tokens)** - Fixed server sets for common workflows
3. **Agent Workspaces (2.5-5k tokens)** - Specialized AI personas with curated tools

**Result:** 14-35x token reduction while maintaining full capability.

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/lessuselesss/comr-flake.git ~/Projects/Flakes/comr-flake
cd ~/Projects/Flakes/comr-flake

# Test semantic routing
nix run . "show git status"

# Test a workspace
nix run .#python-dev "hello world"

# Test an agent workspace
nix run .#security-audit "scan for vulnerabilities"
```

### Daily Usage

```bash
# Semantic routing (AI picks servers)
nix run ~/Projects/Flakes/comr-flake "commit my changes"

# Python development
nix run ~/Projects/Flakes/comr-flake#python-dev "implement user auth"

# Web development with browser testing
nix run ~/Projects/Flakes/comr-flake#web-dev "test login flow"

# Security audit
nix run ~/Projects/Flakes/comr-flake#security-audit "scan this code"

# Code review
nix run ~/Projects/Flakes/comr-flake#code-review "review my PR"
```

## Available Workspaces

### Pre-configured Workspaces

| Workspace | Servers | Use Case |
|-----------|---------|----------|
| `python-dev` | git, sequential-thinking, sqlite, filesystem | Python development |
| `web-dev` | git, sequential-thinking, playwright, github, brave-search | Web development & testing |
| `data-analysis` | git, sequential-thinking, postgres, sqlite, filesystem | Data analysis & ETL |
| `devops` | git, sequential-thinking, docker, aws, github | DevOps & cloud infrastructure |
| `api-dev` | git, sequential-thinking, postgres, slack, stripe | API development |

### Agent-Enhanced Workspaces

| Workspace | Agent Specialty | Use Case |
|-----------|-----------------|----------|
| `security-audit` | OWASP Top 10 scanner | Security vulnerability analysis |
| `code-review` | Senior reviewer (15+ years) | Code quality review |
| `refactor` | Code smell detector | Refactoring recommendations |
| `perf-optimize` | Performance expert | Database & algorithm optimization |
| `accessibility-check` | WCAG 2.1 AA compliance | Accessibility testing |
| `baml-extract` | Type-safe data extraction | Structured data parsing |
| `hackernews` | HN curator | Hacker News frontpage analysis |
| `agent-gateway` | A2A orchestration | Agent Gateway configuration |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Task Input                      │
└─────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
        Semantic Routing          Workspace Selection
        (AI-driven)              (User-specified)
                │                       │
                ▼                       ▼
    ┌────────────────────┐   ┌─────────────────────┐
    │ Intent Analysis    │   │ Pre-configured      │
    │ (gemini-2.0-flash) │   │ Server Set          │
    └────────────────────┘   └─────────────────────┘
                │                       │
                ▼                       ▼
        ┌───────────────────────────────────┐
        │   Minimal MCP Server Selection    │
        │   (2-5 servers vs 80+ all)        │
        └───────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │   Claude Code Execution           │
        │   (70k → 1-5k token overhead)     │
        └───────────────────────────────────┘
```

## Token Comparison

| Approach | Token Usage | Reduction |
|----------|-------------|-----------|
| Default (~/.claude.json) | 70k tokens | Baseline |
| Semantic Routing (comr) | 1-3k tokens | **23-70x less** |
| Pre-configured Workspace | 2-4k tokens | **17-35x less** |
| Agent Workspace | 2.5-5k tokens | **14-28x less** |

## Documentation

- **[WORKSPACE_GUIDE.md](./WORKSPACE_GUIDE.md)** - Comprehensive workspace configuration and usage guide
- **[CLAUDE.md](./CLAUDE.md)** - Project-specific development guidelines

## Creating Custom Workspaces

### Basic Workspace

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
      # Add specialized servers
    }
    "My custom workspace description";
};
```

### Agent Workspace

```nix
my-agent = {
  type = "app";
  program = mkWorkspaceWithAgent "my-agent"
    {
      # Server configuration
    }
    {
      name = "agent-id";
      description = "Agent display name";
      prompt = "You are a specialist in X...";
    }
    "Agent workspace description";
};
```

## Workflow Examples

### Python Development Session

```bash
# Development
nix run ~/Projects/Flakes/comr-flake#python-dev "implement user authentication with SQLite"

# Testing
nix run ~/Projects/Flakes/comr-flake#python-dev "write tests for auth module"

# Review
nix run ~/Projects/Flakes/comr-flake#code-review "review auth implementation"

# Security check
nix run ~/Projects/Flakes/comr-flake#security-audit "scan auth for vulnerabilities"
```

### Web Development Session

```bash
# UI development
nix run ~/Projects/Flakes/comr-flake#web-dev "create login page with form validation"

# Browser testing
nix run ~/Projects/Flakes/comr-flake#web-dev "test login flow with Playwright"

# Accessibility check
nix run ~/Projects/Flakes/comr-flake#accessibility-check "verify WCAG compliance"

# Performance optimization
nix run ~/Projects/Flakes/comr-flake#perf-optimize "analyze page load performance"
```

## Best Practices

1. **Start with semantic routing** - Let AI learn your patterns
2. **Switch to workspaces for repetitive tasks** - 3+ similar tasks = workspace time
3. **Use agent workspaces for expert analysis** - Security, performance, accessibility
4. **Keep related work in same workspace** - Maintains conversation context
5. **Monitor with `/context`** - Track your token savings

## Integration with System Flake

Add to your NixOS/home-manager configuration:

```nix
# flake.nix
{
  inputs.comr = {
    url = "github:lessuselesss/comr-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Add to packages
  home.packages = [
    inputs.comr.packages.${pkgs.system}.default
  ];
}
```

Then use via `comr` command:

```bash
comr "commit my changes"
```

## Requirements

- Nix with flakes enabled
- Claude Code CLI
- Node.js + npm (for npx packages)
- Python 3.11+ + uvx (for Python packages)

## Contributing

See [CLAUDE.md](./CLAUDE.md) for development guidelines.

## License

MIT

## Acknowledgments

- Inspired by [claude-code-open](https://github.com/cyberchitta/claude-code-open)'s provider routing pattern
- Built with the [Model Context Protocol](https://modelcontextprotocol.io/)
- Powered by [Nix](https://nixos.org/) for reproducible environments
