# LLM Cell - Universal Language Model Interface

## Status: ✅ Implemented

Universal interface to all LLM providers (Claude, Gemini, GPT-4, Qwen, Ollama) with cost tracking, intelligent routing, and unified API.

## Files

- **data.nix** - Model registry with costs, capabilities, and provider configurations
- **functions.nix** - Internal utilities (model resolution, cost estimation, token counting)
- **lib.nix** - Public API with three-layer design
- **packages.nix** - llm CLI tool with essential plugins
- **CLAUDE.md** - Detailed planning and architecture

## Key Features

- **Unified API** - Single interface for all providers
- **10+ Models** - Claude, Gemini, GPT-4, Qwen, Ollama
- **Cost Tracking** - Accurate cost estimation before requests
- **Intelligent Routing** - Automatic model selection based on task complexity
- **Model Aliases** - Use `claude` instead of `claude-3.5-sonnet`
- **Config Integration** - Uses config cell for API keys and limits
- **Context Management** - Automatic truncation to fit context windows

## Supported Models

| Model | Provider | Input Cost | Output Cost | Context | Vision | Free Tier |
|-------|----------|-----------|-------------|---------|--------|-----------|
| claude-3.5-sonnet | Anthropic | $3.00/M | $15.00/M | 200K | ✅ | ❌ |
| claude-3.5-haiku | Anthropic | $0.80/M | $4.00/M | 200K | ✅ | ❌ |
| gemini-2.5-pro | Google | $1.25/M | $5.00/M | 2M | ✅ | ❌ |
| gemini-2.0-flash | Google | $0.075/M | $0.30/M | 1M | ✅ | ✅ |
| gemini-2.0-flash-lite | Google | $0.00/M | $0.00/M | 1M | ❌ | ✅ |
| gpt-4o | OpenAI | $2.50/M | $10.00/M | 128K | ✅ | ❌ |
| gpt-4o-mini | OpenAI | $0.15/M | $0.60/M | 128K | ✅ | ❌ |
| qwen-2.5-coder | Qwen | $0.00/M | $0.00/M | 131K | ❌ | ✅ |
| llama-3.2 | Ollama | $0.00/M | $0.00/M | 128K | ❌ | ✅ |
| deepseek-coder-v2 | Ollama | $0.00/M | $0.00/M | 128K | ❌ | ✅ |

*Costs shown per million tokens (M = 1,000,000)*

## CLI Agent Support (New!)

The LLM cell now supports **two execution backends**:

1. **API-based models** - Direct API calls via llm.datasette.io plugins (existing)
2. **CLI-based agents** - Integrated CLI tools with MCP servers, hooks, and plugins (new!)

### CLI Models

| Model | CLI Command | API Equivalent | Features |
|-------|-------------|----------------|----------|
| claude-code-cli | `claude -p --output-format json` | claude-3.5-sonnet | MCP servers, hooks, workspace context |
| gemini-cli | `gemini chat` | gemini-2.0-flash | 70+ extensions, multimodal, web search |
| qwen-cli | `qwen` | qwen-2.5-coder | Free tier, coding optimized |

### When to Use CLI vs API

**Use CLI Agents When:**
- Need MCP server integration (git, postgres, filesystem, etc.)
- Want stateful sessions with conversation history
- Require workspace-aware context
- Need slash commands or hooks
- Want integrated tooling (Claude Code plugins, Gemini extensions)

**Use API Models When:**
- Simple programmatic access
- Stateless requests
- Lower latency requirements
- Batch processing
- Don't need integrated tooling

### Backend Selection Examples

```nix
# Explicit CLI usage
llm.askClaudeCLI "task"      # Uses claude-code-cli
llm.askGeminiCLI "task"      # Uses gemini-cli
llm.askQwenCLI "task"        # Uses qwen-cli

# Explicit API usage (same as before)
llm.askClaude "task"         # Uses claude-3.5-sonnet (API)
llm.askGemini "task"         # Uses gemini-2.0-flash (API)

# Smart backend selection
llm.askSmart "task" { preferCLI = true; }   # Prefer CLI if available
llm.askSmart "task" { preferAPI = true; }   # Prefer API if available
llm.askSmart "task" { requireCLI = true; }  # Force CLI (error if unavailable)

# Ask with backend preference
llm.askWithBackend "cli" "claude" "task"   # Use CLI version of claude
llm.askWithBackend "api" "claude" "task"   # Use API version of claude
```

### Model Equivalence

Each CLI model has an API equivalent:

```nix
# Get equivalents
llm.getModelEquivalents "claude-code-cli"
# Returns: {
#   original = "claude-code-cli";
#   type = "cli";
#   cliEquivalent = "claude-code-cli";
#   apiEquivalent = "claude-3.5-sonnet";
#   hasEquivalents = true;
# }

# Find CLI equivalent of API model
llm.findCLIEquivalent "claude-3.5-sonnet"  # Returns: "claude-code-cli"

# Find API equivalent of CLI model
llm.findAPIEquivalent "claude-code-cli"    # Returns: "claude-3.5-sonnet"
```

### Backend Utility Functions

```nix
# Check backend type
llm.getBackendType "claude-code-cli"  # Returns: "cli"
llm.getBackendType "claude"           # Returns: "api"

# Type checking
llm.isCLIModel "claude-code-cli"      # Returns: true
llm.isAPIModel "claude-3.5-sonnet"    # Returns: true

# List models by backend
llm.listCLIModels {}                  # Returns: ["claude-code-cli" "gemini-cli" "qwen-cli"]
llm.listAPIModels {}                  # Returns: ["claude-3.5-sonnet" "gemini-2.0-flash" ...]

# Get CLI command info
llm.getCLICommand "claude-code-cli"
# Returns: {
#   command = "claude";
#   args = ["-p" "--output-format" "json"];
#   path = "claude";
# }
```

### Installing CLI Tools

To use CLI models, you need the corresponding CLI tools installed:

```bash
# Claude Code CLI (varies by OS)
# See: https://docs.claude.com/claude-code

# Gemini CLI
npm install -g gemini-cli

# Qwen CLI
npm install -g @qwen-code/qwen-code

# Or use Nix packages from agents cells (when implemented)
nix run .#agents.claude-code.packages.claude
nix run .#agents.gemini-cli.packages.gemini
```

**Environment Setup:**

```bash
# API keys (same for both CLI and API)
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
export DASHSCOPE_API_KEY="..."
```

### CLI Plugin Architecture

The llm-cli-agents plugin provides the bridge between llm.datasette.io and CLI tools:

**How it Works:**
1. llm plugin (`llm-cli-agents`) registers CLI models
2. When you call `llm -m claude-code-cli "task"`, the plugin:
   - Builds CLI command: `claude -p --output-format json --model claude-3.5-sonnet "task"`
   - Executes subprocess with proper environment (API keys, PATH)
   - Parses output (JSON for Claude, plain text for Gemini/Qwen)
   - Returns response to llm framework

**Plugin Location**: `cells/llm/llm-cli-agents/`

**Packaging**: Included in `llm-full` and `llm-with-cli-agents` packages

### Cost Tracking

CLI models use the same cost data as their API equivalents:

```nix
# Same cost for API and CLI versions
llm.estimateCost "claude-3.5-sonnet" prompt  # $X
llm.estimateCost "claude-code-cli" prompt    # $X (same)

# Cost guards work for both
llm.askWithGuard "claude-code-cli" "task"
```

### Future CLI Support

Planned CLI integrations:
- [ ] `aider-cli` - AI pair programming
- [ ] `cursor-cli` - Cursor editor CLI
- [ ] `continue-cli` - Continue VSCode extension CLI
- [ ] Custom agent CLIs from agents/* cells

## Exports

### Public API (lib.nix)

#### Layer 1: High-Level API (Simple Usage)

```nix
# Simple ask with model name or alias
llm.ask "claude-3.5-sonnet" "Explain this code"
llm.ask "claude" "Review this PR"  # Alias resolution
llm.ask "gemini" "What is AI?"

# Provider-specific convenience functions
llm.askClaude "task"      # Uses claude-3.5-sonnet
llm.askGemini "task"      # Uses gemini-2.0-flash
llm.askGPT4 "task"        # Uses gpt-4o
llm.askQwen "task"        # Uses qwen-2.5-coder

# Use case-specific functions
llm.askCheap "task"       # Uses gemini-2.0-flash-lite (free)
llm.askFast "task"        # Uses claude-3.5-haiku (fastest)
llm.askLocal "task"       # Uses llama-3.2 (local/private)
```

#### Layer 2: Medium-Level API (Configurable)

```nix
# Configured ask with options
llm.askWith {
  model = "claude-3.5-sonnet";
  temperature = 0.3;  # More deterministic
  maxTokens = 8000;
  system = "You are a code reviewer";
} "Review this code"

# Intelligent ask - automatically selects best model
llm.askSmart "simple task"  # Uses gemini-2.0-flash-lite
llm.askSmart "complex reasoning task"  # Uses claude-3.5-sonnet
llm.askSmart "analyze this 50KB file" {reasoning = true;}

# Cost-optimal ask - cheapest model meeting requirements
llm.askOptimal {
  minContext = 100000;  # Need large context
  vision = true;        # Need vision capability
} "Analyze this image and document"  # Selects best cheap option
```

#### Layer 3: Low-Level API (Full Control)

```nix
# Direct llm command execution
llm.command {
  args = ["prompt" "-m" "claude-3.5-sonnet" "-s" "system prompt" "user prompt"];
  stdin = fileContent;
  env = { CUSTOM_VAR = "value"; };
  model = "claude-3.5-sonnet";  # Auto-injects API key
}
```

#### Utility Functions

```nix
# Cost estimation (before execution)
llm.estimateCost "claude-3.5-sonnet" "long prompt text"
# Returns: { model, inputTokens, estimatedOutputTokens, estimatedCost, provider }

# Context checking
llm.fitsInContext "claude" "very long text"
# Returns: { fits, textTokens, maxInputTokens, contextWindow }

# Truncate to fit context
llm.truncateToContext "gemini" "long document" 2000  # Reserve 2K for output

# Token counting
llm.countTokens "estimate tokens for this text"
# Returns: integer (approximate token count)

# Model resolution
llm.resolveModel "claude"  # Returns: "claude-3.5-sonnet"
llm.resolveModel "gemini"  # Returns: "gemini-2.0-flash"

# List available models (with API keys configured)
llm.listModels
# Returns: ["claude-3.5-sonnet" "gemini-2.0-flash" ...]

# Get model information
llm.getModel "claude"
# Returns: { provider, cost, context, vision, streaming, tools, aliases }

# Model capabilities
llm.getModelCapabilities "claude-3.5-sonnet"

# Compare models
llm.compareModels "claude" "gemini"
# Returns: { caps1, caps2, costDifference, comparison }

# Compare costs
llm.compareCosts ["claude" "gemini" "gpt-4o"] "prompt"
# Returns: { claude = { cost = 0.05; ... }, gemini = { cost = 0.01; ... } }

# Find cheapest
llm.findCheapest ["claude" "gemini" "gpt-4o"] "prompt"
# Returns: "gemini-2.0-flash"

# Health check
llm.healthCheck {}
# Returns: { healthy, apiKeysConfigured, availableModelCount, totalModels }
```

### Packages (packages.nix)

```nix
# llm CLI tool
cell.packages.llm          # Main llm command with plugins
cell.packages.llm-base     # Base llm without plugins
cell.packages.llm-plugins  # Individual plugin packages
cell.packages.llm-full     # llm with all available plugins
```

## Usage Examples

### Estimate Cost Before Execution

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  carefulAsk = model: prompt:
    let
      estimate = llm.estimateCost model prompt;
    in
      if estimate.estimatedCost > 0.10
      then throw "Cost ${builtins.toString estimate.estimatedCost} too high!"
      else llm.ask model prompt;
}
```

### Use Cheapest Model That Meets Requirements

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  efficientAsk = requirements: prompt:
    let
      model = llm.selectCostOptimal requirements;
    in llm.ask model prompt;

  # Usage:
  # efficientAsk { minContext = 50000; vision = true; } "analyze image"
}
```

### Intelligent Model Routing

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  smartProcessor = task:
    let
      # Automatically selects model based on complexity
      # Simple tasks → gemini-2.0-flash-lite (free)
      # Complex tasks → claude-3.5-sonnet (best reasoning)
      result = llm.askSmart task;
    in result;
}
```

### Code Review with Specific Model

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  reviewCode = code:
    llm.askWith {
      model = "claude-3.5-sonnet";
      temperature = 0.3;  # Deterministic for code review
      maxTokens = 8000;
      system = ''
        You are a senior code reviewer.
        Focus on: security, performance, maintainability.
        Provide specific, actionable feedback.
      '';
    } "Review this code:\n\n${code}";
}
```

### Batch Processing

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  processMultiple = files:
    llm.batchAsk "claude" (builtins.map (f: "Summarize: ${f}") files);
}
```

### Integration with Config Cell

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
  config = inputs.cells.config.lib;
in {
  guardedAsk = model: prompt:
    let
      # Check against config cell cost limits
      check = llm.checkCostLimit model prompt;
    in
      if !check.withinLimit
      then throw "Cost exceeds limit: ${builtins.toString check.percentOfLimit}%"
      else llm.ask model prompt;

  # Or use built-in guard
  safeAsk = llm.askWithGuard "claude" "expensive prompt";
}
```

### Truncate Long Documents

```nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  analyzeLongDoc = document:
    let
      # Ensure document fits in context
      truncated = llm.truncateToContext "claude" document 2000;
    in llm.ask "claude" "Analyze: ${truncated}";
}
```

## CLI Usage

```bash
# Ask Claude a question
nix run .#llm.packages.llm -- prompt -m claude-3.5-sonnet "What is Nix?"

# Use alias
nix run .#llm.packages.llm -- prompt -m claude "Explain flakes"

# Interactive chat
nix run .#llm.packages.llm -- chat -m gemini-2.0-flash

# List installed models
nix run .#llm.packages.llm -- models list

# View conversation history
nix run .#llm.packages.llm -- logs list

# Continue previous conversation
nix run .#llm.packages.llm -- chat -c <conversation-id>
```

## Model Selection Guide

### By Use Case

**General Chat** → `gemini-2.0-flash-lite` (free, fast)
**Code Generation** → `claude-3.5-sonnet` (best for code)
**Code Review** → `claude-3.5-sonnet` (best reasoning)
**Vision Tasks** → `gemini-2.5-pro` (best vision + large context)
**Fast Responses** → `claude-3.5-haiku` (lowest latency)
**Budget-Conscious** → `gemini-2.0-flash-lite` (free tier)
**Privacy-First** → `llama-3.2` (local, offline)
**Long Documents** → `gemini-2.5-pro` (2M context)

### By Provider

**Anthropic (Claude)**
- Best reasoning and code generation
- Excellent instruction following
- High quality, higher cost
- Models: claude-3.5-sonnet, claude-3.5-haiku

**Google (Gemini)**
- Best value (free tier available)
- Huge context windows (up to 2M tokens)
- Good vision capabilities
- Models: gemini-2.5-pro, gemini-2.0-flash, gemini-2.0-flash-lite

**OpenAI (GPT-4)**
- Well-rounded capabilities
- Good for general tasks
- Moderate cost
- Models: gpt-4o, gpt-4o-mini

**Qwen (Alibaba)**
- Free code generation
- Good for Chinese language
- Models: qwen-2.5-coder

**Ollama (Local)**
- Privacy-first (runs locally)
- No API costs
- Lower quality than cloud models
- Models: llama-3.2, deepseek-coder-v2

## Model Aliases

Use short aliases instead of full model names:

### API Models

| Alias | Resolves To |
|-------|-------------|
| `claude` | claude-3.5-sonnet |
| `sonnet` | claude-3.5-sonnet |
| `haiku` | claude-3.5-haiku |
| `gemini` | gemini-2.0-flash |
| `flash` | gemini-2.0-flash |
| `gemini-lite` | gemini-2.0-flash-lite |
| `gemini-pro` | gemini-2.5-pro |
| `gpt4` | gpt-4o |
| `openai` | gpt-4o |
| `qwen` | qwen-2.5-coder |
| `coder` | qwen-2.5-coder |
| `llama` | llama-3.2 |
| `deepseek` | deepseek-coder-v2 |

### CLI Models

| Alias | Resolves To |
|-------|-------------|
| `claude-cli` | claude-code-cli |
| `cc` | claude-code-cli |
| `gcli` | gemini-cli |
| `qc` | qwen-cli |

## API Key Setup

The llm cell uses the config cell for API key management. See [cells/config/README.md](../config/README.md) for details.

**Quick Setup:**

```bash
# Initialize config
nix run .#config.runnables.init

# Set API keys
nix run .#config.runnables.set-key -- anthropic keyring
nix run .#config.runnables.set-key -- google keyring

# Or use environment variables
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
export OPENAI_API_KEY="sk-..."
export DASHSCOPE_API_KEY="sk-..."
```

## Dependencies

### Required
- `nixpkgs` - For Python and llm package
- `cells.config` - For API key management

### External
- llm.datasette.io (Python package)
- llm-claude-3 (plugin)
- llm-gemini (plugin)
- llm-ollama (plugin, optional)

### Cells That Consume This Cell
- **agents/*** - All agents use llm for unified interface
- **orchestrators** - Uses llm for multi-agent coordination
- **routing** - Uses llm for intent analysis
- **workspaces** - Uses llm for model selection
- **diagnostics** - Uses llm for cost tracking

## Integration Examples

### Agent Cell Integration

```nix
# cells/agents/claude-code/functions.nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  runTask = task:
    # Use LLM cell's unified interface
    llm.askClaude task;
}
```

### Orchestrator Cell Integration

```nix
# cells/orchestrators/functions.nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  multiModelConsensus = task:
    let
      claudeResponse = llm.ask "claude" task;
      geminiResponse = llm.ask "gemini" task;
      gpt4Response = llm.ask "gpt-4o" task;
    in aggregateResponses [claudeResponse geminiResponse gpt4Response];
}
```

### Workspace Cell Integration

```nix
# cells/workspaces/functions.nix
{inputs, cell}: let
  llm = inputs.cells.llm.lib;
in {
  selectWorkspaceModel = workspaceType:
    if workspaceType == "dev"
    then llm.getDefaultModel "cheap"  # gemini-2.0-flash-lite
    else if workspaceType == "prod"
    then llm.getDefaultModel "reasoning"  # claude-3.5-sonnet
    else llm.getDefaultModel "chat";
}
```

## Cost Management

### Estimate Before Execution

Always estimate costs for expensive operations:

```nix
let
  estimate = llm.estimateCost "claude-3.5-sonnet" longPrompt;
in
  if estimate.estimatedCost > 1.00
  then builtins.trace "Warning: High cost ${builtins.toString estimate.estimatedCost}" result
  else result
```

### Use Cost Guards

```nix
# Automatically enforces config cell limits
llm.askWithGuard "claude" "expensive task"
# Throws if cost exceeds maxCostPerRequest from config
```

### Compare Costs

```nix
let
  costs = llm.compareCosts ["claude" "gemini" "gpt-4o"] "task";
  cheapest = llm.findCheapest ["claude" "gemini" "gpt-4o"] "task";
in
  llm.ask cheapest "task"  # Uses cheapest option
```

## Troubleshooting

### API Key Not Found

```bash
# Check configured keys
nix run .#config.runnables.list-keys

# Set missing key
nix run .#config.runnables.set-key -- anthropic keyring
```

### Model Not Available

```bash
# List available models (with API keys)
nix eval .#llm.lib.listModels

# Check health
nix eval .#llm.lib.healthCheck
```

### Cost Limit Exceeded

```nix
# Check current limits
nix run .#config.runnables.show

# Increase limit
nix run .#config.runnables.set -- profiles.dev.limits.maxCostPerRequest 5.00
```

### Context Too Large

```nix
# Check if fits
let
  check = llm.fitsInContext "claude" largeDocument;
in
  if !check.fits
  then llm.truncateToContext "claude" largeDocument
  else largeDocument
```

## Performance Tips

1. **Use Free Tier Models** - `gemini-2.0-flash-lite` is free and fast
2. **Batch Requests** - Process multiple prompts together
3. **Cache Results** - Save expensive LLM calls (future feature)
4. **Smart Routing** - Let `askSmart` choose the right model
5. **Truncate Early** - Check context limits before sending
6. **Estimate Costs** - Always estimate before expensive calls

## Future Enhancements

Planned features:
- [ ] Response caching (semantic + exact match)
- [ ] Request batching for compatible models
- [ ] Streaming support in Nix
- [ ] Rate limiting with exponential backoff
- [ ] Performance monitoring integration
- [ ] Conversation history management
- [ ] Template system for reusable prompts
- [ ] Multi-model consensus aggregation

## References

- **Planning**: See [CLAUDE.md](./CLAUDE.md) for detailed architecture
- **Simon Willison's LLM**: https://llm.datasette.io
- **Config Cell**: See [cells/config/README.md](../config/README.md)
- **Model Pricing**: Check provider websites for latest costs
