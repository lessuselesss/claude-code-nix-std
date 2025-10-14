# Config Cell - Centralized Configuration Management

## Status: ✅ Implemented

Centralized configuration and API key management for the entire framework. Single source of truth for model preferences, cost caps, rate limits, and credentials across all agents, workspaces, and orchestrators.

## Files

- **types.nix** - Nix type definitions for validation
- **data.nix** - Default configurations and model registry
- **functions.nix** - Validation and secrets management
- **lib.nix** - Public configuration API
- **runnables.nix** - CLI tools (hybrid Bash + Nushell)
- **CLAUDE.md** - Detailed planning and architecture

## Exports

### Public API (lib functions)

#### High-Level API (Layer 1)

```nix
# Get API key for a provider
getApiKey "anthropic"  # Returns API key string

# Get default model for a task type
getDefaultModel "chat"      # For general chat
getDefaultModel "reasoning" # For reasoning tasks
getDefaultModel "code"      # For code generation

# Get cost cap for a limit type
getCostCap "maxCostPerRequest"
getCostCap "maxCostPerDay"
getCostCap "maxCostPerMonth"

# Get rate limit
getRateLimit "requestsPerMinute"
getRateLimit "concurrentRequests"

# Get model information
getModel "claude-3.5-sonnet"  # Returns model metadata
```

#### Medium-Level API (Layer 2)

```nix
# Validate configuration
validate {
  apiKeys = { anthropic = "sk-..."; };
  preferences = { defaultModel = "claude-3.5-sonnet"; };
  limits = { maxCostPerDay = 10; };
}

# Load environment profile
loadProfile "dev"      # Load development profile
loadProfile "staging"  # Load staging profile
loadProfile "prod"     # Load production profile

# Switch active profile
switchProfile "prod"

# Estimate request cost
estimateCost {
  model = "claude-3.5-sonnet";
  inputTokens = 1000;
  outputTokens = 500;
}  # Returns cost in USD

# Check if cost exceeds limits
checkCostLimit 2.50 "maxCostPerRequest"
# Returns: { ok = true/false; warning = true/false; }
```

#### Low-Level API (Layer 3)

```nix
# Build configuration from scratch
build {
  schema = {...};
  source = "environment" | "keyring" | "age-encrypted";
  profile = "dev" | "staging" | "prod";
}

# Merge multiple configurations
merge [config1 config2 config3]
```

#### Utility Functions

```nix
# List all available models
listModels  # Returns attrset of models

# List all profiles
listProfiles  # Returns ["dev" "staging" "prod"]

# Get environment variable name for provider
getEnvVarName "anthropic"  # Returns "ANTHROPIC_API_KEY"

# Check if provider requires API key
requiresApiKey "github"  # Returns true/false
```

### CLI Tools (runnables)

All tools are accessed via `nix run .#config.runnables.<tool>` or `comr config <tool>` if aliased.

#### Bash Tools (Interactive Operations)

```bash
# Initialize configuration
nix run .#config.runnables.init
# Creates ~/.config/comr/config.json with defaults

# Set API key (interactive)
nix run .#config.runnables.set-key -- anthropic environment
nix run .#config.runnables.set-key -- anthropic keyring
nix run .#config.runnables.set-key -- anthropic age-encrypted
# Prompts for key securely (hidden input)

# Get configuration value
nix run .#config.runnables.get -- activeProfile
nix run .#config.runnables.get -- profiles.dev.preferences.defaultModel

# Set configuration value
nix run .#config.runnables.set -- activeProfile staging
nix run .#config.runnables.set -- profiles.dev.limits.maxCostPerDay 10

# Switch active profile
nix run .#config.runnables.switch-profile -- prod

# Validate configuration
nix run .#config.runnables.validate
# Checks: file exists, valid JSON, required fields present
```

#### Nushell Tools (Data Display & Analysis)

```bash
# Display configuration with beautiful tables
nix run .#config.runnables.show
# Shows: active profile, preferences, cost limits, rate limits, API key status

# List API key status for all providers
nix run .#config.runnables.list-keys
# Table with provider, status (✅/❌), expected format, format validation

# Compare two profiles side-by-side
nix run .#config.runnables.compare-profiles -- dev prod
# Tables comparing: preferences, cost limits, rate limits
```

## Features

### Configuration Profiles

Three pre-configured environment profiles with different cost/risk tolerances:

| Setting | dev | staging | prod |
|---------|-----|---------|------|
| **Default Model** | gemini-2.0-flash-lite (cheapest) | claude-3.5-sonnet | claude-3.5-sonnet |
| **Temperature** | 0.7 (exploratory) | 0.5 (balanced) | 0.3 (deterministic) |
| **Max Cost/Request** | $0.50 | $1.00 | $2.00 |
| **Max Cost/Day** | $5.00 | $20.00 | $50.00 |
| **Max Cost/Month** | $100.00 | $500.00 | $1000.00 |
| **Hard Stop** | ❌ Warn only | ✅ Enabled | ✅ Enabled |
| **Requests/Minute** | 60 | 30 | 20 |
| **Concurrent Requests** | 3 | 2 | 1 (most conservative) |
| **Experimental Features** | ✅ Allowed | ❌ Disabled | ❌ Disabled |

### API Key Storage Methods

Three storage backends with increasing security:

**1. Environment Variables (Default)**
- Simple, cross-platform
- Keys stored in shell profile or `.env` files
- ⚠️ Visible in process list and environment dumps

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
```

**2. System Keyring (Secure)**
- OS-integrated secret storage
- Uses `secret-tool` (GNOME Keyring on Linux)
- ✅ Encrypted at rest
- ✅ Protected by OS authentication

```bash
nix run .#config.runnables.set-key -- anthropic keyring
# Prompts for password, stores securely
```

**3. Age-Encrypted Files (Portable)**
- Encrypted with [age](https://github.com/FiloSottile/age)
- Portable across machines
- ✅ Encrypted at rest (age encryption)
- ⚠️ Requires age key backup

```bash
nix run .#config.runnables.set-key -- anthropic age-encrypted
# Generates age key, encrypts secrets
# Backup ~/.config/comr/age-key.txt!
```

### Cost Tracking & Limits

**Cost Estimation:**
```nix
# Calculate cost before making request
let cost = config.estimateCost {
  model = "claude-3.5-sonnet";
  inputTokens = 5000;
  outputTokens = 1000;
};
# cost = (5 * 0.003) + (1 * 0.015) = $0.030

# Check against limits
config.checkCostLimit cost "maxCostPerRequest"
# Returns: { ok = true; warning = false; }
```

**Cost Caps:**
- Per-request caps (prevent runaway single requests)
- Daily caps (control daily spending)
- Monthly caps (budget management)
- Warn threshold (alert at 80% by default)
- Hard stop vs. warn-only modes

### Rate Limiting

**Per-Profile Limits:**
- Requests per minute (RPM)
- Requests per hour (RPH)
- Tokens per minute (TPM)
- Concurrent requests (parallelism)
- Backoff strategy (exponential/linear/constant)

**Example:**
```nix
# Production profile: Most conservative
rateLimits = {
  requestsPerMinute = 20;
  requestsPerHour = 500;
  tokensPerMinute = 50000;
  concurrentRequests = 1;
  backoffStrategy = "exponential";
};
```

### Model Registry

Centralized model definitions with cost and capability metadata:

```nix
models = {
  "claude-3.5-sonnet" = {
    provider = "anthropic";
    context = 200000;
    costPer1kTokens = { input = 0.003; output = 0.015; };
    capabilities = ["chat" "function-calling" "vision" "code-generation" "reasoning"];
  };

  "gemini-2.0-flash-lite" = {
    provider = "google";
    context = 1048576;
    costPer1kTokens = { input = 0.0; output = 0.0; };  # Free tier
    capabilities = ["chat" "function-calling" "code-generation"];
  };

  # ... 6 models total (Claude, Gemini, GPT-4, Qwen)
};
```

### API Key Requirements

Per-cell API key requirements with format validation:

```nix
apiKeyRequirements = {
  llm = {
    anthropic = { required = false; keyFormat = "sk-ant-.*"; };
    google = { required = false; keyFormat = ".*"; };
  };

  agents.claude-code = {
    anthropic = { required = true; keyFormat = "sk-ant-.*"; };
  };

  mcp.github = {
    github = { required = true; keyFormat = "gh[ps]_.*"; };
  };

  # ... requirements for all cells
};
```

## Usage Examples

### Initialize Configuration

```bash
# First time setup
nix run .#config.runnables.init

# Output:
# 🔧 Initializing comr configuration...
# ✅ Configuration initialized at ~/.config/comr/config.json
#
# Next steps:
# 1. Set API keys: export ANTHROPIC_API_KEY=sk-...
# 2. Or use keyring: comr config set-key anthropic keyring
# 3. Configure preferences: comr config show
```

### Set API Keys

**Environment variables:**
```bash
nix run .#config.runnables.set-key -- anthropic environment

# Output:
# 🔑 Setting API key for anthropic using environment storage...
# Add to your shell profile:
#   export ANTHROPIC_API_KEY=your-key-here
```

**System keyring:**
```bash
nix run .#config.runnables.set-key -- anthropic keyring

# Prompts:
# 🔑 Setting API key for anthropic using keyring storage...
# Enter API key for anthropic: ••••••••••••••••
# ✅ API key stored in system keyring
```

**Age-encrypted:**
```bash
nix run .#config.runnables.set-key -- google age-encrypted

# Prompts:
# 🔑 Setting API key for google using age-encrypted storage...
# Enter API key for google: ••••••••••••••••
# ⚠️  Age key generated. BACKUP THIS FILE: ~/.config/comr/age-key.txt
# ✅ API key encrypted and stored
```

### View Configuration

```bash
nix run .#config.runnables.show

# Output:
# 📋 Configuration Overview
# =========================
#
# Active Profile: dev
#
# User Preferences:
#   Default Model: gemini-2.0-flash-lite
#   Default Reasoning Model: claude-3.5-sonnet
#   Default Code Model: claude-3.5-sonnet
#   Temperature: 0.7
#   Max Tokens: 4096
#   Stream Responses: true
#
# Cost Limits:
#   Max Cost Per Request: $0.5
#   Max Cost Per Day: $5.0
#   Max Cost Per Month: $100.0
#   Max Tokens Per Request: 100000
#   Warn Threshold: 80%
#   Hard Stop: false
#
# Rate Limits:
#   Requests Per Minute: 60
#   Concurrent Requests: 3
#   Backoff Strategy: exponential
#
# Storage:
#   API Keys: environment
#   Config Dir: $HOME/.config/comr
#
# Telemetry:
#   Enabled: false
```

### Check API Key Status

```bash
nix run .#config.runnables.list-keys

# Output:
# 🔑 API Keys Status
# =================
#
# ╭──────────────┬────────────┬──────────────────╮
# │ provider     │ status     │ format_expected  │
# ├──────────────┼────────────┼──────────────────┤
# │ anthropic    │ ✅ Set     │ sk-ant-*         │
# │ google       │ ✅ Set     │ *                │
# │ openai       │ ❌ Not Set │ sk-*             │
# │ openrouter   │ ❌ Not Set │ sk-or-*          │
# │ dashscope    │ ❌ Not Set │ sk-*             │
# │ github       │ ✅ Set     │ gh[ps]_*         │
# │ slack        │ ❌ Not Set │ xoxb-*           │
# │ huggingface  │ ❌ Not Set │ hf_*             │
# ╰──────────────┴────────────┴──────────────────╯
```

### Switch Profiles

```bash
# Switch from dev to production
nix run .#config.runnables.switch-profile -- prod

# Output:
# 🔄 Switching to profile: prod
# ✅ Set activeProfile = prod
# ✅ Active profile: prod
```

### Compare Profiles

```bash
nix run .#config.runnables.compare-profiles -- dev prod

# Output:
# 🔄 Comparing Profiles: dev vs prod
# ==================================================
#
# User Preferences:
# ╭────────────────────────┬──────────────────────────┬────────────────────╮
# │ setting                │ dev                      │ prod               │
# ├────────────────────────┼──────────────────────────┼────────────────────┤
# │ Default Model          │ gemini-2.0-flash-lite    │ claude-3.5-sonnet  │
# │ Temperature            │ 0.7                      │ 0.3                │
# │ Max Tokens             │ 4096                     │ 4096               │
# ╰────────────────────────┴──────────────────────────┴────────────────────╯
#
# Cost Limits:
# ╭──────────────────────┬────────┬─────────╮
# │ setting              │ dev    │ prod    │
# ├──────────────────────┼────────┼─────────┤
# │ Max Cost Per Request │ 0.5    │ 2.0     │
# │ Max Cost Per Day     │ 5.0    │ 50.0    │
# │ Hard Stop            │ false  │ true    │
# ╰──────────────────────┴────────┴─────────╯
#
# Rate Limits:
# ╭─────────────────────────┬──────┬───────╮
# │ setting                 │ dev  │ prod  │
# ├─────────────────────────┼──────┼───────┤
# │ Requests Per Minute     │ 60   │ 20    │
# │ Concurrent Requests     │ 3    │ 1     │
# ╰─────────────────────────┴──────┴───────╯
```

### Programmatic Usage (From Other Cells)

```nix
# cells/llm/functions.nix
{inputs, cell}: let
  config = inputs.cells.config.lib;
in {
  # Get API key for LLM provider
  makeRequest = provider: prompt:
    let
      apiKey = config.getApiKey provider;
      model = config.getDefaultModel "chat";

      # Estimate cost before request
      estimatedCost = config.estimateCost {
        model = model.name;
        inputTokens = 1000;
        outputTokens = 500;
      };

      # Check cost limit
      costCheck = config.checkCostLimit estimatedCost "maxCostPerRequest";
    in
      if !costCheck.ok
      then throw "Cost $${toString estimatedCost} exceeds limit"
      else if costCheck.warning
      then builtins.trace "WARNING: ${costCheck.message}" (doRequest apiKey model prompt)
      else doRequest apiKey model prompt;
};
```

### Validate Configuration

```bash
nix run .#config.runnables.validate

# Output:
# 🔍 Validating configuration...
# ✅ Configuration is valid

# Or if errors:
# 🔍 Validating configuration...
# ❌ Config file not found: ~/.config/comr/config.json
# ❌ Invalid JSON syntax
# ❌ Missing required field: profiles
```

## Configuration File Location

Default: `~/.config/comr/config.json`

**Structure:**
```json
{
  "version": "1.0.0",
  "activeProfile": "dev",
  "profiles": {
    "dev": { /* ... */ },
    "staging": { /* ... */ },
    "prod": { /* ... */ }
  },
  "storage": {
    "apiKeys": "environment",
    "configDir": "$HOME/.config/comr"
  },
  "telemetry": {
    "enabled": false
  }
}
```

## Dependencies

### Inputs Required
- `nixpkgs` - For jq, age, bash, nushell, libsecret
- No cell dependencies (config is foundation-level)

### External Tools (Optional)
- `secret-tool` (libsecret-tools) - For keyring storage
- `age` - For age-encrypted storage
- `jq` - For JSON manipulation

### Cells That Consume This Cell

All cells depend on config for centralized configuration:

- **llm** - API keys, model selection, cost estimation
- **agents/*** - API keys, model preferences
- **orchestrators** - Cost limits, rate limits
- **mcp** - API keys for MCP servers (GitHub, Slack, etc.)
- **workspaces** - Profile selection, cost tracking
- **diagnostics** - Telemetry configuration
- **routing** - Model selection
- **prompts** - Model capabilities

## Integration Example

### Agent Cell Integration

```nix
# cells/agents/claude-code/functions.nix
{inputs, cell}: let
  config = inputs.cells.config;
in {
  # Run Claude Code with config management
  runClaudeCode = task:
    let
      # Get API key from config
      apiKey = config.lib.getApiKey "anthropic";

      # Get model preference
      model = config.lib.getDefaultModel "code";

      # Get rate limit
      rateLimit = config.lib.getRateLimit "requestsPerMinute";

      # Check required keys
      _ = config.functions.checkRequiredKeys "agents.claude-code";
    in
      runWithConfig apiKey model rateLimit task;
};
```

### Workspace Cell Integration

```nix
# cells/workspaces/functions.nix
{inputs, cell}: let
  config = inputs.cells.config;
in {
  # Create workspace with cost tracking
  createWorkspace = name: servers:
    let
      # Load active profile
      profile = config.lib.loadProfile config.data.defaults.activeProfile;

      # Check API keys for required servers
      checkServerKeys = server:
        let
          provider = serverToProvider server;
          required = config.data.apiKeyRequirements.mcp.${server}.required or false;
        in
          if required
          then config.lib.getApiKey provider != ""
          else true;

      allKeysPresent = builtins.all checkServerKeys servers;
    in
      if !allKeysPresent
      then throw "Missing required API keys for workspace ${name}"
      else buildWorkspace name servers profile;
};
```

## Security Considerations

1. **API Key Storage**
   - Never commit API keys to git
   - Use `.gitignore` for `secrets.age`, `.env` files
   - Prefer keyring or age-encrypted over environment variables

2. **File Permissions**
   - Config directory: `~/.config/comr/` (755)
   - Age key file: `~/.config/comr/age-key.txt` (600)
   - Secrets file: `~/.config/comr/secrets.age` (600)

3. **Key Rotation**
   - Rotate keys periodically
   - Update in all storage locations
   - Test after rotation

4. **Backup**
   - ⚠️ **CRITICAL**: Backup `~/.config/comr/age-key.txt` if using age encryption
   - Without this key, encrypted secrets are unrecoverable
   - Store backup securely (password manager, encrypted USB, etc.)

## Migration from Existing Configs

### From comr (Old System)

```bash
# Old config location
~/.config/comr/servers.json

# Migration path
# 1. Initialize new config
nix run .#config.runnables.init

# 2. Manually migrate API keys
nix run .#config.runnables.set-key -- anthropic keyring

# 3. Adjust preferences
nix run .#config.runnables.set -- profiles.dev.preferences.defaultModel claude-3.5-sonnet
```

### From Claude Code Settings

```bash
# Old config location
~/.claude/settings.json

# Migration path
# 1. Extract MCP servers (handled by mcp cell)
# 2. Extract API keys
# 3. Initialize new config with similar preferences
```

## Troubleshooting

### API Key Not Found

```bash
# Check status
nix run .#config.runnables.list-keys

# Set key
nix run .#config.runnables.set-key -- anthropic environment
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Invalid Configuration

```bash
# Validate
nix run .#config.runnables.validate

# If errors, reinitialize
mv ~/.config/comr/config.json ~/.config/comr/config.json.backup
nix run .#config.runnables.init
```

### Cost Limit Exceeded

```bash
# Check current profile
nix run .#config.runnables.show

# Increase limit
nix run .#config.runnables.set -- profiles.dev.limits.maxCostPerDay 20

# Or switch to higher-limit profile
nix run .#config.runnables.switch-profile -- staging
```

### Age Key Lost

⚠️ **If you lose `~/.config/comr/age-key.txt`, encrypted secrets are unrecoverable!**

Recovery steps:
1. Generate new age key: `nix run .#config.runnables.set-key -- anthropic age-encrypted`
2. Re-enter all API keys
3. **Backup the new key immediately**

## Future Enhancements

Planned features:
- [ ] Automatic cost tracking from telemetry logs
- [ ] Budget alerts (email/webhook notifications)
- [ ] Usage analytics and cost trends
- [ ] API key expiration warnings
- [ ] Multi-user configuration (team settings)
- [ ] Remote configuration sync
- [ ] Configuration templates for common setups

## References

- **Planning**: See [CLAUDE.md](./CLAUDE.md) for detailed architecture
- **Migration**: See [MIGRATION.md](../../MIGRATION.md) for migration guide
- **Type System**: See [types.nix](./types.nix) for validation schemas
- **Model Registry**: See [data.nix](./data.nix) for model definitions
