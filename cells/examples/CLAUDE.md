# Examples Cell - User Extensibility Templates

## Purpose

Provide examples and templates for users to create custom workspaces, agents, orchestrations, and prompts without modifying core framework.

## Files

```
cells/examples/
├── CLAUDE.md
├── custom-workspaces.nix      # Workspace templates
├── custom-agents.nix           # Agent templates
├── custom-orchestrators.nix    # Orchestration templates
├── custom-prompts.nix          # Prompt templates
└── lib.nix                     # Helper functions
```

## Implementation

**custom-workspaces.nix:**
```nix
{inputs, cell}: {
  my-workspace = inputs.cells.workspaces.lib.compose {
    agents = ["claude-code"];
    servers = ["git" "custom-server"];
  };
}
```

**custom-agents.nix:**
```nix
{
  my-agent = {
    name = "my-agent";
    description = "Custom agent";
    prompt = "You are...";
    servers = ["git"];
  };
}
```

## Migration Guide

### From Current comr to divnix std

This guide covers migrating from the monolithic `comr-flake` to the modular `claude-code-nix-std` architecture.

#### Overview of Changes

**Before (comr-flake):**
- Single `flake.nix` (1115 lines)
- Inline workspace definitions
- Direct Claude Code CLI calls
- Manual MCP server management
- No agent orchestration

**After (claude-code-nix-std):**
- Modular cells (11 cells, ~100 lines each)
- Composable workspaces
- Universal LLM interface
- Automatic MCP server discovery
- Multi-agent orchestration patterns

#### Step 1: Understand New Architecture

```
claude-code-nix-std/
├── flake.nix (root, using std.growOn)
└── cells/
    ├── llm/              # Universal LLM interface (replaces direct claude calls)
    ├── mcp/              # MCP server registry (100+ servers)
    ├── agents/
    │   └── claude-code/  # Claude Code agent (current workspaces live here)
    ├── routing/          # Semantic server selection (current comr semantic routing)
    ├── workspaces/       # Workspace composition
    ├── orchestrators/    # Multi-agent coordination
    ├── prompts/          # DSPy prompt optimization
    ├── marketplaces/     # Plugin discovery
    ├── config/           # Centralized configuration
    ├── diagnostics/      # Observability
    └── examples/         # This cell - user extensibility
```

#### Step 2: Migrate MCP Server Configuration

**Old Format (`~/.config/comr/servers.json`):**
```json
{
  "mcpServers": {
    "git": {
      "command": "uvx",
      "args": ["mcp-server-git"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"]
    }
  }
}
```

**New Format (Automatic via Registry):**
```nix
# No manual configuration needed!
# Servers auto-discovered from cells/mcp/data.nix

# To use a server:
inputs.cells.mcp.lib.getServer "git"
inputs.cells.mcp.lib.getServer "postgres"
```

**Migration Script:**
```bash
# Copy existing servers to new location
mkdir -p ~/.config/claude-code-nix-std
cp ~/.config/comr/servers.json ~/.config/claude-code-nix-std/legacy-servers.json

# Servers will be automatically discovered from MCP registry
# No manual migration needed for standard servers
```

#### Step 3: Migrate Workspaces

**Old Workspace (comr-flake):**
```nix
# flake.nix lines 343-400
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

**New Workspace (divnix std):**
```nix
# cells/agents/claude-code/data.nix
{
  workspaces = {
    python-dev = {
      agent = "claude-code";
      servers = ["git" "sequential-thinking" "sqlite" "filesystem"];
      prompts = [];
      orchestration = null;
    };
  };
}

# Usage unchanged:
nix run .#python-dev "implement feature"
```

**Custom User Workspace:**
```nix
# cells/examples/custom-workspaces.nix
{inputs, cell}: {
  my-python-dev = inputs.cells.workspaces.lib.compose {
    agents = ["claude-code"];
    servers = ["git" "postgres" "sqlite" "my-custom-server"];
    prompts = ["code-review"];
  };
}

# Usage:
nix run .#examples.custom-workspaces.my-python-dev -- "task"
```

#### Step 4: Migrate Agent Workspaces

**Old Agent Workspace (comr-flake):**
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
      prompt = "You are a security auditor...";
    }
    "Security audit workspace";
};
```

**New Agent Workspace:**
```nix
# cells/agents/claude-code/data.nix
{
  agents = {
    security = {
      name = "security";
      description = "Security auditor";
      prompt = "You are a security auditor. Scan for OWASP Top 10...";
      servers = ["git" "sequential-thinking" "filesystem"];
    };
  };
}

# Usage unchanged:
nix run .#security-audit "scan for vulnerabilities"
```

#### Step 5: Migrate Semantic Routing

**Old Semantic Routing (comr):**
```bash
# flake.nix lines 343-577
comr "what is the git status"
# Uses gemini-2.0-flash-lite for intent analysis
# Selects git + sequential-thinking servers
# Executes via Claude Code
```

**New Semantic Routing:**
```nix
# cells/routing/lib.nix handles this automatically
nix run .#comr "what is the git status"

# Or explicit:
inputs.cells.routing.lib.analyze "task"
# Returns: ["git" "sequential-thinking"]
```

#### Step 6: Add API Keys

**Old Format (Environment Variables):**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
```

**New Format (Managed by Config Cell):**
```bash
# Option 1: Environment variables (still works)
export ANTHROPIC_API_KEY="sk-ant-..."

# Option 2: System keyring (recommended)
nix run .#config.runnables.set-key -- anthropic keyring

# Option 3: Age-encrypted secrets
nix run .#config.runnables.set-key -- anthropic age-encrypted

# View configuration:
nix run .#config.runnables.show
```

#### Step 7: Use Multi-Agent Orchestration (New Feature)

**Not available in old comr, but now:**
```nix
# cells/examples/custom-orchestrators.nix
{inputs, cell}: {
  # LangGraph: Security audit pipeline
  security-pipeline = inputs.cells.orchestrators.lib.buildGraph {
    nodes = {
      scanner = {
        name = "static-analyzer";
        model = "claude-3.5-sonnet";
      };
      validator = {
        name = "security-validator";
        model = "gemini-2.0-flash";
      };
      reporter = {
        name = "report-generator";
        model = "claude-3.5-sonnet";
      };
    };
    edges = [
      { from = "scanner"; to = "validator"; }
      { from = "validator"; to = "reporter"; condition = "has_findings"; }
    ];
  };

  # CrewAI: Code review team
  code-review-team = inputs.cells.orchestrators.lib.crewai {
    manager = {
      name = "senior-reviewer";
      model = "claude-3.5-sonnet";
    };
    workers = [
      { name = "security-reviewer"; model = "claude-3.5-sonnet"; }
      { name = "performance-reviewer"; model = "gemini-2.0-flash"; }
    ];
  } "review this PR";
}

# Usage:
nix run .#examples.custom-orchestrators.security-pipeline -- "audit codebase"
```

#### Step 8: Add Custom MCP Server

**Old Way (Manual Configuration):**
```json
// ~/.config/comr/servers.json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@myorg/mcp-server"]
    }
  }
}
```

**New Way (Cell Configuration):**
```nix
# cells/examples/custom-servers.nix
{inputs, cell}: {
  my-server = inputs.cells.mcp.lib.mkServer {
    name = "my-server";
    command = "npx";
    args = ["-y" "@myorg/mcp-server"];
    env = { MY_API_KEY = "$MY_API_KEY"; };
    capabilities = ["custom-capability"];
  };
}

# Register in workspace:
{
  my-workspace = inputs.cells.workspaces.lib.compose {
    agents = ["claude-code"];
    servers = ["git" "my-server"];
  };
}
```

#### Step 9: Enable Observability

**New Feature - Diagnostics:**
```bash
# View real-time logs
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

#### Step 10: Use Prompt Optimization (New Feature)

**DSPy Integration:**
```nix
# cells/examples/custom-prompts.nix
{inputs, cell}: {
  # Use pre-optimized prompt
  security-audit-prompt = inputs.cells.prompts.lib.use "security-audit" {
    code = readFile ./src/auth.py;
    context = "FastAPI authentication";
  };

  # Optimize custom prompt
  my-optimized-prompt = inputs.cells.prompts.lib.optimize {
    signature = "code,context -> review";
    examples = [
      {
        code = "def foo(): pass";
        context = "Simple function";
        review = "Function is empty, add implementation";
      }
    ];
    optimizer = "mipro";
  };
}
```

#### Step 11: Session Continuation

**Old Way (Manual):**
```bash
# No built-in continuation support
nix run .#python-dev "task 1"
# ... work ...
nix run .#python-dev "task 2"  # Lost context from task 1
```

**New Way (Automatic State Management):**
```bash
# First task
nix run .#python-dev "implement authentication"
# Session ID: abc123

# Continue session (with context)
nix run .#python-dev -- --continue "add tests for auth"

# Or resume by session ID
nix run .#workspaces.runnables.resume -- abc123 "refactor auth code"

# List active sessions
nix run .#workspaces.runnables.sessions
```

### Backward Compatibility

The new architecture maintains backward compatibility:

```bash
# Old commands still work:
nix run .#python-dev "task"
nix run .#security-audit "task"
nix run . "semantic routing task"  # comr

# New features available:
nix run .#python-dev -- --continue "task"
nix run .#orchestrators.langgraph-security-audit "task"
nix run .#diagnostics.cost-report
```

### Migration Checklist

- [ ] Copy `~/.config/comr/servers.json` to `~/.config/claude-code-nix-std/legacy-servers.json`
- [ ] Set up API keys using new config cell
- [ ] Test existing workspaces still work
- [ ] Migrate custom MCP servers to cells/examples/
- [ ] Create custom workspaces in cells/examples/ if needed
- [ ] Enable diagnostics and monitoring
- [ ] Review cost reports and optimize
- [ ] Explore multi-agent orchestration patterns
- [ ] Try DSPy prompt optimization
- [ ] Use session continuation for long tasks

### Common Migration Issues

**Issue 1: "Server not found"**
```bash
# Old server name doesn't match registry
# Solution: Check registry
nix eval .#mcp.lib.searchServers '"postgres"'
```

**Issue 2: "API key not set"**
```bash
# Solution: Configure via config cell
nix run .#config.runnables.set-key -- anthropic environment
```

**Issue 3: "Workspace behavior changed"**
```bash
# Solution: Check new workspace definition
nix eval .#agents.claude-code.data.workspaces.python-dev
```

### Getting Help

```bash
# Show available cells
nix flake show

# Show workspace servers
nix eval .#agents.claude-code.data.workspaces.python-dev.servers

# Show MCP registry
nix eval .#mcp.data.servers --apply 'builtins.attrNames'

# Health check
nix run .#diagnostics.health-check
```

## Example Templates

### Template 1: Custom Workspace with Private MCP Server

```nix
# cells/examples/custom-workspaces.nix
{inputs, cell}: let
  # Define custom MCP server
  privateServer = inputs.cells.mcp.lib.mkServer {
    name = "my-company-server";
    command = "nix";
    args = ["run" "github:mycompany/mcp-servers#internal-tools" "--"];
    env = { COMPANY_API_KEY = "$COMPANY_API_KEY"; };
    capabilities = ["company-data" "internal-apis"];
  };
in {
  # Workspace using private server
  company-dev = inputs.cells.workspaces.lib.compose {
    agents = ["claude-code"];
    servers = ["git" "sequential-thinking" "my-company-server"];
    prompts = ["code-review"];
  };
}

# Usage:
# export COMPANY_API_KEY="..."
# nix run .#examples.custom-workspaces.company-dev -- "query internal data"
```

### Template 2: Multi-Agent Security Review

```nix
# cells/examples/custom-orchestrators.nix
{inputs, cell}: {
  comprehensive-security-review = inputs.cells.orchestrators.lib.buildGraph {
    nodes = {
      static-analysis = {
        name = "static-analyzer";
        model = "claude-3.5-sonnet";
        description = "Perform static code analysis";
      };

      dependency-audit = {
        name = "dependency-auditor";
        model = "gemini-2.0-flash";
        description = "Audit dependencies for vulnerabilities";
      };

      penetration-test = {
        name = "pen-tester";
        model = "claude-3.5-sonnet";
        description = "Simulate penetration testing";
      };

      report-aggregator = {
        name = "report-writer";
        model = "claude-3.5-sonnet";
        description = "Generate comprehensive security report";
      };
    };

    edges = [
      { from = "static-analysis"; to = "report-aggregator"; }
      { from = "dependency-audit"; to = "report-aggregator"; }
      { from = "penetration-test"; to = "report-aggregator"; }
    ];

    state = {
      findings = [];
      severity_counts = { critical = 0; high = 0; medium = 0; low = 0; };
    };
  };
}

# Usage:
# nix run .#examples.custom-orchestrators.comprehensive-security-review -- \
#   "Review authentication system in src/auth/"
```

### Template 3: Cost-Optimized Workspace

```nix
# cells/examples/custom-workspaces.nix
{inputs, cell}: {
  budget-dev = {
    # Use cheapest models
    agent = "claude-code";
    servers = ["git" "sequential-thinking"];

    # Cost optimization config
    config = {
      # Use Gemini for simple tasks
      routing = "intelligent";  # Automatically route to cheaper models

      # Enable aggressive caching
      caching = {
        enabled = true;
        ttl = 86400;  # 24 hours
        semantic = true;  # Cache similar prompts
      };

      # Set cost limits
      limits = {
        maxCostPerRequest = 0.10;
        maxCostPerDay = 5.00;
      };

      # Prefer free-tier models
      modelPreference = ["gemini-2.0-flash-lite" "gemini-2.0-flash" "claude-3.5-haiku"];
    };
  };
}
```

### Template 4: Research Workspace with RAG

```nix
# cells/examples/custom-workspaces.nix
{inputs, cell}: {
  research-workspace = inputs.cells.workspaces.lib.compose {
    agents = ["qwen"];  # Qwen has built-in RAG support

    servers = [
      "git"
      "sequential-thinking"
      "brave-search"
      "exa"  # Advanced web research
      "filesystem"
    ];

    prompts = ["research-analysis"];

    config = {
      # RAG configuration
      rag = {
        enabled = true;
        documentPaths = ["./docs" "./research" "./papers"];
        embeddingModel = "all-mpnet-base-v2";
        chunkSize = 512;
        overlap = 50;
      };

      # Long context for research
      contextWindow = 256000;  # Use Qwen's 256K context
    };
  };
}

# Usage:
# nix run .#examples.custom-workspaces.research-workspace -- \
#   "Research quantum computing applications in cryptography, cite sources"
```

### Template 5: Custom Slash Command

```nix
# cells/examples/custom-commands.nix
{inputs, cell}: {
  # Define custom slash command
  detailed-review = {
    name = "/detailed-review";
    description = "Comprehensive code review with security, performance, and style analysis";

    prompt = inputs.cells.prompts.lib.build {
      template = ''
        You are conducting a detailed code review. Analyze the following aspects:

        1. **Security**: Check for OWASP Top 10 vulnerabilities
        2. **Performance**: Identify bottlenecks, O(n²) algorithms, missing indexes
        3. **Code Style**: PEP 8 (Python), ESLint (JS), rustfmt (Rust)
        4. **Maintainability**: Function complexity, code duplication, naming
        5. **Test Coverage**: Missing tests, edge cases

        Code to review:
        ```
        {{code}}
        ```

        Context: {{context}}

        Provide a structured report with severity levels and actionable recommendations.
      '';

      vars = {
        code = "...";
        context = "...";
      };
    };

    servers = ["git" "filesystem" "sequential-thinking"];
    agent = "claude-3.5-sonnet";
  };
}

# Usage:
# nix run .#agents.claude-code.custom-command -- \
#   detailed-review src/auth.py "Authentication module"
```

## Success Criteria

- [ ] 10+ examples provided
- [ ] Templates are usable
- [ ] Documentation complete
- [ ] Users can extend framework
- [ ] Migration guide covers all common scenarios
- [ ] Backward compatibility maintained
- [ ] Migration scripts tested
- [ ] Common issues documented with solutions
- [ ] Performance comparison (old vs new) provided
