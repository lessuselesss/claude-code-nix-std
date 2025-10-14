# Routing Cell - Semantic MCP Server Selection

## Purpose

Extract current semantic routing logic from comr. AI-driven intent analysis to select optimal MCP servers based on task requirements. Reduces token usage from 70k to 1-3k.

## Key Features

- **Intent Analysis**: Gemini 2.0 Flash Lite analyzes task
- **Server Selection**: Chooses minimal server set
- **Routing Rules**: Keyword-based + AI-driven
- **Baseline Servers**: Always include git + sequential-thinking
- **Cost Optimization**: Prefer cheaper models for routing

## Three-Layer API

**Layer 1:**
```nix
routing.analyze "commit these changes"  # Returns ["git", "sequential-thinking"]
routing.analyze "query database"        # Returns ["git", "sequential-thinking", "postgres"]
```

**Layer 2:**
```nix
routing.analyzeWith {
  model = "gemini-2.0-flash-lite";
  availableServers = ["git" "postgres" "github"];
  baseline = ["git" "sequential-thinking"];
  rules = {...};
}
```

**Layer 3:**
```nix
routing.selectServers {
  task = "...";
  registry = {...};
  rules = {...};
  strategy = "minimal" | "comprehensive";
}
```

## Files

```
cells/routing/
├── CLAUDE.md
├── lib.nix          # Routing API
├── functions.nix    # Intent analysis, selection logic
├── data.nix         # Routing rules, keywords
└── runnables.nix    # comr CLI (current semantic router)
```

## Implementation Plan

### Phase 1: Extract Routing Logic (Week 2, Days 5-7)

**data.nix:**
```nix
{
  rules = {
    keywords = {
      git = ["commit" "push" "diff" "branch" "merge"];
      postgres = ["database" "query" "sql" "table" "schema"];
      github = ["issues" "pr" "pull request" "repository"];
      playwright = ["browser" "test" "e2e" "screenshot"];
      # ... keyword rules for all servers
    };

    baseline = ["git" "sequential-thinking"];

    # Capability-based rules
    capabilities = {
      "version-control" = ["git"];
      "database" = ["postgres" "sqlite"];
      "browser-automation" = ["playwright"];
      "api-integration" = ["github" "slack" "stripe"];
    };
  };

  models = {
    intent-analyzer = "gemini-2.0-flash-lite";  # Cheap + fast
    fallback = "claude-3.5-sonnet";
  };
}
```

**lib.nix:**
```nix
{
  analyze = task:
    cell.functions.intentAnalysis {
      inherit task;
      model = cell.data.models.intent-analyzer;
      availableServers = inputs.cells.mcp.lib.getAllServers;
      rules = cell.data.rules;
    };

  analyzeWith = { model, availableServers, baseline ? cell.data.rules.baseline, rules ? cell.data.rules }:
    task: cell.functions.intentAnalysis { inherit task model availableServers baseline rules; };

  selectServers = { task, registry, rules, strategy ? "minimal" }:
    cell.functions.ruleBasedSelection { inherit task registry rules strategy; };
}
```

**functions.nix:**
```nix
{
  intentAnalysis = { task, model, availableServers, baseline, rules }:
    let
      # Build prompt for intent analysis
      availableList = builtins.concatStringsSep "\n" (
        builtins.map (s: "- ${s}: ${inputs.cells.mcp.data.servers.${s}.description}") availableServers
      );

      prompt = ''
        Analyze this task and determine which MCP servers are needed.

        Available MCP servers:
        ${availableList}

        Rules:
        1. ALWAYS include: ${builtins.concatStringsSep ", " baseline}
        2. Add specialized servers ONLY if task explicitly needs them
        3. Minimize server count for token efficiency
        4. Prefer configured servers over registry servers
        5. If unsure, use only baseline servers

        Task: ${task}

        Return ONLY a valid JSON array of server names, e.g.: ["git", "sequential-thinking", "postgres"]
      '';

      # Execute via llm
      response = inputs.cells.llm.lib.askWith {
        inherit model;
        system = "You are a server selection expert. Respond only with JSON arrays.";
        temperature = 0.3;  # More deterministic
      } prompt;

      # Parse response
      servers = builtins.fromJSON response;
    in if builtins.isList servers then servers else baseline;

  ruleBasedSelection = { task, registry, rules, strategy }:
    let
      taskLower = builtins.toLower task;

      # Keyword matching
      matchedServers = builtins.filter (server:
        let keywords = rules.keywords.${server} or [];
        in builtins.any (kw: builtins.match ".*${kw}.*" taskLower != null) keywords
      ) (builtins.attrNames registry);

      # Always include baseline
      selected = rules.baseline ++ matchedServers;

      # Remove duplicates
      unique = builtins.foldl' (acc: s: if builtins.elem s acc then acc else acc ++ [s]) [] selected;
    in
      if strategy == "minimal"
      then builtins.take 5 unique  # Limit to 5 servers max
      else unique;
}
```

### Phase 2: Migrate comr CLI (Week 3, Days 1-2)

**runnables.nix:**
```nix
{
  # Current comr semantic router
  comr = pkgs.writeShellScriptBin "comr" ''
    #!/usr/bin/env bash
    # Extract current comr logic (lines 343-577 from flake.nix.backup)
    # Use cells.routing.lib.analyze
    # Execute via cells.agents.claude-code
  '';
}
```

## Dependencies

- Inputs: `cells.llm`, `cells.mcp`
- External: None (pure routing logic)
- Consumes: `llm` for intent analysis, `mcp` for server registry
- Produces for: `workspaces`, unified `comr` interface

## Migration

Current `comr` (flake.nix lines 343-577) → `cells/routing/runnables.nix`

## Success Criteria

- [ ] Intent analysis matches current behavior
- [ ] Token usage 1-3k (same as current)
- [ ] Baseline servers always included
- [ ] Keyword matching works
- [ ] comr CLI functional
