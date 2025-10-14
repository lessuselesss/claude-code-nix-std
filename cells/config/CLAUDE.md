# Config Cell - Centralized Configuration Management

## Purpose

Provide centralized configuration and API key management for the entire framework. Single source of truth for model preferences, cost caps, rate limits, and credentials across all agents, workspaces, and orchestrators.

## Key Features

- **API Key Management**: Secure storage for 10+ API providers
- **Schema Validation**: Nix type system for config validation
- **Environment Profiles**: dev/staging/prod configurations
- **User Preferences**: Default models, cost caps, rate limits
- **Migration Tools**: Import existing configs (comr, Claude Code, Gemini CLI)
- **Secrets Management**: Keyring, age-encrypted, or environment variable storage

## Three-Layer API

**Layer 1:**
```nix
config.getApiKey "anthropic"
config.getDefaultModel "chat"
config.getCostCap "workspace"
```

**Layer 2:**
```nix
config.validate {
  apiKeys = { anthropic = "sk-..."; google = "..."; };
  preferences = { defaultModel = "claude-3.5-sonnet"; };
  limits = { maxCostPerDay = 10; };
}
```

**Layer 3:**
```nix
config.build {
  schema = {...};
  source = "file" | "keyring" | "age-encrypted";
  profile = "dev" | "staging" | "prod";
}
```

## Files

```
cells/config/
├── CLAUDE.md
├── lib.nix          # Configuration API
├── data.nix         # Schema definitions, defaults
├── functions.nix    # Validation, migration, secrets
├── runnables.nix    # Config management tools
└── types.nix        # Nix type system for validation
```

## Implementation Plan

### Phase 1: Configuration Schema (Week 7, Days 1-2)

**types.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  lib = pkgs.lib;
in rec {
  # API key type
  apiKeyType = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.enum [
          "anthropic"
          "google"
          "openai"
          "openrouter"
          "azure"
          "huggingface"
          "aws"
          "stripe"
          "github"
          "slack"
        ];
        description = "API provider name";
      };

      key = lib.mkOption {
        type = lib.types.str;
        description = "API key value";
      };

      keyFormat = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Expected key format regex (e.g., 'sk-.*')";
      };

      required = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this key is required for operation";
      };

      scopes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Required scopes/permissions for this key";
      };
    };
  };

  # Model preference type
  modelType = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.enum ["anthropic" "google" "openai" "openrouter"];
        description = "Model provider";
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "Model name (e.g., 'claude-3.5-sonnet')";
      };

      context = lib.mkOption {
        type = lib.types.int;
        description = "Context window size in tokens";
      };

      costPer1kTokens = lib.mkOption {
        type = lib.types.submodule {
          options = {
            input = lib.mkOption { type = lib.types.float; };
            output = lib.mkOption { type = lib.types.float; };
          };
        };
        description = "Cost per 1000 tokens (USD)";
      };

      capabilities = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [
          "chat"
          "function-calling"
          "vision"
          "code-generation"
          "reasoning"
        ]);
        description = "Model capabilities";
      };
    };
  };

  # User preferences type
  preferencesType = lib.types.submodule {
    options = {
      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "claude-3.5-sonnet";
        description = "Default model for chat tasks";
      };

      defaultReasoningModel = lib.mkOption {
        type = lib.types.str;
        default = "claude-3.5-sonnet";
        description = "Default model for reasoning tasks";
      };

      defaultCodeModel = lib.mkOption {
        type = lib.types.str;
        default = "claude-3.5-sonnet";
        description = "Default model for code generation";
      };

      temperature = lib.mkOption {
        type = lib.types.float;
        default = 0.7;
        description = "Default temperature (0.0-1.0)";
      };

      maxTokens = lib.mkOption {
        type = lib.types.int;
        default = 4096;
        description = "Default max tokens for responses";
      };

      streamResponses = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to stream responses";
      };
    };
  };

  # Cost limits type
  limitsType = lib.types.submodule {
    options = {
      maxCostPerRequest = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "Max cost per single request (USD)";
      };

      maxCostPerDay = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "Max total cost per day (USD)";
      };

      maxCostPerMonth = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "Max total cost per month (USD)";
      };

      maxTokensPerRequest = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Max tokens per request (input + output)";
      };

      warnThresholdPercent = lib.mkOption {
        type = lib.types.int;
        default = 80;
        description = "Warn when reaching this % of limit";
      };

      hardStop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Hard stop when limit reached vs. warn only";
      };
    };
  };

  # Rate limit type
  rateLimitType = lib.types.submodule {
    options = {
      requestsPerMinute = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Max requests per minute";
      };

      requestsPerHour = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Max requests per hour";
      };

      tokensPerMinute = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Max tokens per minute";
      };

      concurrentRequests = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Max concurrent requests";
      };

      backoffStrategy = lib.mkOption {
        type = lib.types.enum ["exponential" "linear" "constant"];
        default = "exponential";
        description = "Backoff strategy for rate limit errors";
      };
    };
  };

  # Environment profile type
  profileType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.enum ["dev" "staging" "prod"];
        description = "Environment name";
      };

      apiKeys = lib.mkOption {
        type = lib.types.attrsOf apiKeyType;
        default = {};
        description = "API keys for this environment";
      };

      preferences = lib.mkOption {
        type = preferencesType;
        description = "User preferences for this environment";
      };

      limits = lib.mkOption {
        type = limitsType;
        description = "Cost limits for this environment";
      };

      rateLimits = lib.mkOption {
        type = rateLimitType;
        description = "Rate limits for this environment";
      };

      allowExperimentalFeatures = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to allow experimental features";
      };
    };
  };

  # Main config type
  configType = lib.types.submodule {
    options = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "1.0.0";
        description = "Config schema version";
      };

      activeProfile = lib.mkOption {
        type = lib.types.enum ["dev" "staging" "prod"];
        default = "dev";
        description = "Currently active profile";
      };

      profiles = lib.mkOption {
        type = lib.types.attrsOf profileType;
        description = "Environment profiles";
      };

      storage = lib.mkOption {
        type = lib.types.submodule {
          options = {
            apiKeys = lib.mkOption {
              type = lib.types.enum ["environment" "keyring" "age-encrypted" "file"];
              default = "environment";
              description = "How to store API keys";
            };

            secretsFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to secrets file (if storage=age-encrypted)";
            };

            configDir = lib.mkOption {
              type = lib.types.path;
              default = "$HOME/.config/comr";
              description = "Config directory";
            };
          };
        };
        description = "Storage configuration";
      };

      telemetry = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enabled = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to collect telemetry";
            };

            endpoint = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Telemetry endpoint URL";
            };
          };
        };
        default = { enabled = false; endpoint = null; };
        description = "Telemetry configuration";
      };
    };
  };
}
```

**data.nix:**
```nix
{inputs, cell}: {
  # Default configuration
  defaults = {
    version = "1.0.0";
    activeProfile = "dev";

    profiles = {
      dev = {
        name = "dev";
        apiKeys = {};  # Set via environment or keyring

        preferences = {
          defaultModel = "gemini-2.0-flash-lite";  # Cheapest for dev
          defaultReasoningModel = "claude-3.5-sonnet";
          defaultCodeModel = "claude-3.5-sonnet";
          temperature = 0.7;
          maxTokens = 4096;
          streamResponses = true;
        };

        limits = {
          maxCostPerRequest = 0.50;  # $0.50 per request
          maxCostPerDay = 5.00;      # $5 per day
          maxCostPerMonth = 100.00;  # $100 per month
          maxTokensPerRequest = 100000;
          warnThresholdPercent = 80;
          hardStop = false;  # Warn only in dev
        };

        rateLimits = {
          requestsPerMinute = 60;
          requestsPerHour = null;
          tokensPerMinute = null;
          concurrentRequests = 3;
          backoffStrategy = "exponential";
        };

        allowExperimentalFeatures = true;
      };

      staging = {
        name = "staging";
        apiKeys = {};

        preferences = {
          defaultModel = "claude-3.5-sonnet";
          defaultReasoningModel = "claude-3.5-sonnet";
          defaultCodeModel = "claude-3.5-sonnet";
          temperature = 0.5;  # More deterministic
          maxTokens = 4096;
          streamResponses = true;
        };

        limits = {
          maxCostPerRequest = 1.00;
          maxCostPerDay = 20.00;
          maxCostPerMonth = 500.00;
          maxTokensPerRequest = 200000;
          warnThresholdPercent = 80;
          hardStop = true;
        };

        rateLimits = {
          requestsPerMinute = 30;
          requestsPerHour = 1000;
          tokensPerMinute = 100000;
          concurrentRequests = 2;
          backoffStrategy = "exponential";
        };

        allowExperimentalFeatures = false;
      };

      prod = {
        name = "prod";
        apiKeys = {};

        preferences = {
          defaultModel = "claude-3.5-sonnet";
          defaultReasoningModel = "claude-3.5-sonnet";
          defaultCodeModel = "claude-3.5-sonnet";
          temperature = 0.3;  # Most deterministic
          maxTokens = 4096;
          streamResponses = false;  # More reliable
        };

        limits = {
          maxCostPerRequest = 2.00;
          maxCostPerDay = 50.00;
          maxCostPerMonth = 1000.00;
          maxTokensPerRequest = 200000;
          warnThresholdPercent = 90;
          hardStop = true;
        };

        rateLimits = {
          requestsPerMinute = 20;
          requestsPerHour = 500;
          tokensPerMinute = 50000;
          concurrentRequests = 1;  # Most conservative
          backoffStrategy = "exponential";
        };

        allowExperimentalFeatures = false;
      };
    };

    storage = {
      apiKeys = "environment";
      secretsFile = null;
      configDir = "$HOME/.config/comr";
    };

    telemetry = {
      enabled = false;
      endpoint = null;
    };
  };

  # API key requirements per cell
  apiKeyRequirements = {
    # LLM cell
    llm = {
      anthropic = { required = false; keyFormat = "sk-ant-.*"; };
      google = { required = false; keyFormat = ".*"; };
      openai = { required = false; keyFormat = "sk-.*"; };
      openrouter = { required = false; keyFormat = "sk-or-.*"; };
    };

    # Agent cells
    agents = {
      claude-code = {
        anthropic = { required = true; keyFormat = "sk-ant-.*"; };
      };
      gemini-cli = {
        google = { required = true; keyFormat = ".*"; };
      };
      qwen = {
        dashscope = { required = true; keyFormat = "sk-.*"; };
      };
    };

    # Workspace cells
    workspaces = {
      huggingface = {
        huggingface = { required = true; keyFormat = "hf_.*"; };
      };
      zen-agents = {
        google = { required = true; keyFormat = ".*"; };
        openrouter = { required = true; keyFormat = "sk-or-.*"; };
      };
    };

    # MCP servers
    mcp = {
      github = {
        github = { required = true; keyFormat = "gh[ps]_.*"; };
      };
      slack = {
        slack = { required = true; keyFormat = "xoxb-.*"; };
      };
      stripe = {
        stripe = { required = true; keyFormat = "sk_(test|live)_.*"; };
      };
      aws = {
        aws = {
          required = true;
          keys = ["AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY"];
        };
      };
      brave-search = {
        brave = { required = true; keyFormat = "BS.*"; };
      };
    };
  };

  # Model registry
  models = {
    # Anthropic
    "claude-3.5-sonnet" = {
      provider = "anthropic";
      name = "claude-3-5-sonnet-20241022";
      context = 200000;
      costPer1kTokens = { input = 0.003; output = 0.015; };
      capabilities = ["chat" "function-calling" "vision" "code-generation" "reasoning"];
    };

    "claude-3.5-haiku" = {
      provider = "anthropic";
      name = "claude-3-5-haiku-20241022";
      context = 200000;
      costPer1kTokens = { input = 0.0008; output = 0.004; };
      capabilities = ["chat" "function-calling" "vision" "code-generation"];
    };

    # Google
    "gemini-2.0-flash" = {
      provider = "google";
      name = "gemini-2.0-flash";
      context = 1048576;  # 1M
      costPer1kTokens = { input = 0.0; output = 0.0; };  # Free tier
      capabilities = ["chat" "function-calling" "vision" "code-generation" "reasoning"];
    };

    "gemini-2.0-flash-lite" = {
      provider = "google";
      name = "gemini-2.0-flash-lite";
      context = 1048576;
      costPer1kTokens = { input = 0.0; output = 0.0; };  # Free tier
      capabilities = ["chat" "function-calling" "code-generation"];
    };

    # OpenAI (via OpenRouter)
    "gpt-4" = {
      provider = "openrouter";
      name = "openai/gpt-4";
      context = 8192;
      costPer1kTokens = { input = 0.03; output = 0.06; };
      capabilities = ["chat" "function-calling" "code-generation"];
    };

    # Qwen
    "qwen-3-coder" = {
      provider = "dashscope";
      name = "qwen-3-coder";
      context = 262144;  # 256K
      costPer1kTokens = { input = 0.0; output = 0.0; };  # Check actual pricing
      capabilities = ["chat" "function-calling" "code-generation"];
    };
  };

  # Configuration file locations
  configPaths = {
    # Current comr
    comr = {
      servers = "$HOME/.config/comr/servers.json";
      registry = "$HOME/.config/comr/server-registry.json";
    };

    # Claude Code
    claude-code = {
      settings = "$HOME/.claude/settings.json";
      plugins = "$HOME/.claude/plugins/";
    };

    # Gemini CLI
    gemini-cli = {
      config = "$HOME/.config/gemini/config.yaml";
      extensions = "$HOME/.config/gemini/extensions/";
    };

    # New unified config
    unified = {
      config = "$HOME/.config/comr/config.json";
      secrets = "$HOME/.config/comr/secrets.age";
      profiles = "$HOME/.config/comr/profiles/";
    };
  };
}
```

### Phase 2: Configuration Management (Week 7, Days 3-4)

**lib.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  lib = pkgs.lib;
in rec {
  # High-level: Get API key
  getApiKey = provider:
    let
      profile = loadProfile cell.data.defaults.activeProfile;
      storageMethod = cell.data.defaults.storage.apiKeys;
    in
      if storageMethod == "environment"
      then cell.functions.getFromEnv provider
      else if storageMethod == "keyring"
      then cell.functions.getFromKeyring provider
      else if storageMethod == "age-encrypted"
      then cell.functions.getFromAge provider
      else throw "Unknown storage method: ${storageMethod}";

  # High-level: Get default model
  getDefaultModel = taskType:
    let
      profile = loadProfile cell.data.defaults.activeProfile;
      modelName =
        if taskType == "chat" then profile.preferences.defaultModel
        else if taskType == "reasoning" then profile.preferences.defaultReasoningModel
        else if taskType == "code" then profile.preferences.defaultCodeModel
        else profile.preferences.defaultModel;
    in cell.data.models.${modelName};

  # High-level: Get cost cap
  getCostCap = limitType:
    let profile = loadProfile cell.data.defaults.activeProfile;
    in profile.limits.${limitType};

  # High-level: Get rate limit
  getRateLimit = limitType:
    let profile = loadProfile cell.data.defaults.activeProfile;
    in profile.rateLimits.${limitType};

  # Medium-level: Validate config
  validate = config:
    let
      # Type check using Nix type system
      checked = lib.modules.check cell.types.configType config;
    in
      if checked.success
      then config
      else throw "Config validation failed: ${builtins.toJSON checked.errors}";

  # Medium-level: Load profile
  loadProfile = profileName:
    let
      configFile = "${cell.data.configPaths.unified.config}";
      config = if builtins.pathExists configFile
               then builtins.fromJSON (builtins.readFile configFile)
               else cell.data.defaults;
    in config.profiles.${profileName};

  # Medium-level: Switch profile
  switchProfile = profileName:
    cell.functions.updateConfig {
      activeProfile = profileName;
    };

  # Low-level: Build config
  build = { schema, source, profile }:
    cell.functions.buildConfig { inherit schema source profile; };

  # Low-level: Merge configs
  merge = configs:
    builtins.foldl' (acc: cfg: lib.recursiveUpdate acc cfg) {} configs;
}
```

**functions.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # Get API key from environment
  getFromEnv = provider:
    let
      envVars = {
        anthropic = "ANTHROPIC_API_KEY";
        google = "GEMINI_API_KEY";
        openai = "OPENAI_API_KEY";
        openrouter = "OPENROUTER_API_KEY";
        dashscope = "DASHSCOPE_API_KEY";
        huggingface = "HF_TOKEN";
        github = "GITHUB_TOKEN";
        slack = "SLACK_TOKEN";
        stripe = "STRIPE_API_KEY";
        aws = ["AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY"];
        brave = "BRAVE_API_KEY";
      };

      varName = envVars.${provider} or null;
    in
      if varName == null
      then throw "Unknown provider: ${provider}"
      else if builtins.isList varName
      then builtins.map (v: builtins.getEnv v) varName
      else builtins.getEnv varName;

  # Get API key from system keyring
  getFromKeyring = provider:
    pkgs.runCommand "get-keyring-${provider}" {
      buildInputs = [ pkgs.libsecret ];
    } ''
      secret-tool lookup service comr provider ${provider} > $out
    '';

  # Get API key from age-encrypted file
  getFromAge = provider:
    let
      secretsFile = cell.data.defaults.storage.secretsFile;
    in pkgs.runCommand "get-age-${provider}" {
      buildInputs = [ pkgs.age pkgs.jq ];
    } ''
      ${pkgs.age}/bin/age -d ${secretsFile} \
        | ${pkgs.jq}/bin/jq -r '.apiKeys.${provider}' \
        > $out
    '';

  # Validate API key format
  validateApiKey = provider: key:
    let
      requirements = cell.data.apiKeyRequirements;
      format = requirements.${provider}.keyFormat or null;
    in
      if format == null
      then true
      else builtins.match format key != null;

  # Check if required API keys are set
  checkRequiredKeys = cell:
    let
      requirements = cell.data.apiKeyRequirements.${cell} or {};
      missing = builtins.filter (provider:
        let
          key = cell.lib.getApiKey provider;
        in key == "" || key == null
      ) (builtins.attrNames (builtins.filter (k: k.required) requirements));
    in
      if missing != []
      then throw "Missing required API keys for ${cell}: ${builtins.concatStringsSep ", " missing}"
      else true;

  # Update config file
  updateConfig = updates:
    let
      configFile = "${cell.data.configPaths.unified.config}";
      currentConfig = if builtins.pathExists configFile
                      then builtins.fromJSON (builtins.readFile configFile)
                      else cell.data.defaults;
      newConfig = pkgs.lib.recursiveUpdate currentConfig updates;
    in pkgs.writeText "config.json" (builtins.toJSON newConfig);

  # Build config from schema
  buildConfig = { schema, source, profile }:
    let
      baseConfig = cell.data.defaults;
      profileConfig = baseConfig.profiles.${profile};
    in cell.lib.validate (pkgs.lib.recursiveUpdate baseConfig {
      activeProfile = profile;
      storage = { apiKeys = source; };
    });

  # Migrate from existing config
  migrateFromComr = comrConfigPath:
    let
      comrConfig = builtins.fromJSON (builtins.readFile comrConfigPath);
    in {
      # Extract MCP servers
      mcpServers = comrConfig.mcpServers or {};

      # Create unified config
      version = "1.0.0";
      activeProfile = "dev";
      profiles = cell.data.defaults.profiles;
    };

  migrateFromClaudeCode = claudeSettingsPath:
    let
      claudeSettings = builtins.fromJSON (builtins.readFile claudeSettingsPath);
    in {
      # Extract MCP servers
      mcpServers = claudeSettings.mcpServers or {};

      # Extract preferences
      preferences = {
        defaultModel = claudeSettings.defaultModel or "claude-3.5-sonnet";
        maxTokens = claudeSettings.maxTokens or 4096;
        streamResponses = claudeSettings.stream or true;
      };
    };

  # Calculate cost estimate
  estimateCost = { model, inputTokens, outputTokens }:
    let
      modelInfo = cell.data.models.${model};
      inputCost = (inputTokens / 1000.0) * modelInfo.costPer1kTokens.input;
      outputCost = (outputTokens / 1000.0) * modelInfo.costPer1kTokens.output;
    in inputCost + outputCost;

  # Check if cost limit exceeded
  checkCostLimit = cost: limitType:
    let
      limit = cell.lib.getCostCap limitType;
      warnThreshold = cell.lib.getCostCap "warnThresholdPercent";
    in
      if limit == null
      then { ok = true; warning = false; }
      else if cost > limit
      then { ok = false; warning = false; error = "Cost ${builtins.toString cost} exceeds limit ${builtins.toString limit}"; }
      else if cost > (limit * warnThreshold / 100.0)
      then { ok = true; warning = true; message = "Cost ${builtins.toString cost} is ${builtins.toString (cost / limit * 100)}% of limit"; }
      else { ok = true; warning = false; };
}
```

### Phase 3: Configuration Tools (Week 7, Days 5-7)

**runnables.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # Initialize config
  init = pkgs.writeShellScriptBin "comr-config-init" ''
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_DIR="${cell.data.configPaths.unified.config}"
    mkdir -p "$(dirname "$CONFIG_DIR")"

    echo "🔧 Initializing comr configuration..."

    # Create default config
    cat > "$CONFIG_DIR" <<'EOF'
    ${builtins.toJSON cell.data.defaults}
    EOF

    echo "✅ Configuration initialized at $CONFIG_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Set API keys: export ANTHROPIC_API_KEY=sk-..."
    echo "2. Or use keyring: comr config set-key anthropic"
    echo "3. Configure preferences: comr config set defaultModel claude-3.5-sonnet"
  '';

  # Set API key
  set-key = pkgs.writeShellScriptBin "comr-config-set-key" ''
    #!/usr/bin/env bash
    set -euo pipefail

    PROVIDER="$1"
    STORAGE="${2:-environment}"

    echo "🔑 Setting API key for $PROVIDER using $STORAGE storage..."

    if [[ "$STORAGE" == "environment" ]]; then
      echo "Add to your shell profile:"
      echo "  export $(echo $PROVIDER | tr '[:lower:]' '[:upper:]')_API_KEY=your-key-here"

    elif [[ "$STORAGE" == "keyring" ]]; then
      echo "Enter API key for $PROVIDER:"
      read -s API_KEY
      secret-tool store --label="comr $PROVIDER API Key" service comr provider "$PROVIDER" <<< "$API_KEY"
      echo "✅ API key stored in keyring"

    elif [[ "$STORAGE" == "age-encrypted" ]]; then
      echo "Enter API key for $PROVIDER:"
      read -s API_KEY

      SECRETS_FILE="${cell.data.configPaths.unified.secrets}"
      AGE_KEY_FILE="$HOME/.config/comr/age-key.txt"

      # Generate age key if not exists
      if [[ ! -f "$AGE_KEY_FILE" ]]; then
        ${pkgs.age}/bin/age-keygen -o "$AGE_KEY_FILE"
        echo "⚠️  Age key generated. BACKUP THIS FILE: $AGE_KEY_FILE"
      fi

      # Read existing secrets or create new
      if [[ -f "$SECRETS_FILE" ]]; then
        SECRETS=$(${pkgs.age}/bin/age -d -i "$AGE_KEY_FILE" "$SECRETS_FILE")
      else
        SECRETS="{}"
      fi

      # Update secrets
      UPDATED=$(echo "$SECRETS" | ${pkgs.jq}/bin/jq ".apiKeys.\"$PROVIDER\" = \"$API_KEY\"")

      # Encrypt and save
      echo "$UPDATED" | ${pkgs.age}/bin/age -e -i "$AGE_KEY_FILE" -o "$SECRETS_FILE"
      echo "✅ API key encrypted and stored"
    fi
  '';

  # Get config value
  get = pkgs.writeShellScriptBin "comr-config-get" ''
    #!/usr/bin/env bash
    CONFIG_FILE="${cell.data.configPaths.unified.config}"

    KEY="$1"

    ${pkgs.jq}/bin/jq -r ".$KEY" "$CONFIG_FILE"
  '';

  # Set config value
  set = pkgs.writeShellScriptBin "comr-config-set" ''
    #!/usr/bin/env bash
    CONFIG_FILE="${cell.data.configPaths.unified.config}"

    KEY="$1"
    VALUE="$2"

    # Update config
    TEMP=$(mktemp)
    ${pkgs.jq}/bin/jq ".$KEY = \"$VALUE\"" "$CONFIG_FILE" > "$TEMP"
    mv "$TEMP" "$CONFIG_FILE"

    echo "✅ Set $KEY = $VALUE"
  '';

  # Switch profile
  switch-profile = pkgs.writeShellScriptBin "comr-config-switch-profile" ''
    #!/usr/bin/env bash
    PROFILE="$1"

    echo "🔄 Switching to profile: $PROFILE"

    ${cell.runnables.set}/bin/comr-config-set "activeProfile" "$PROFILE"

    echo "✅ Active profile: $PROFILE"
  '';

  # Show current config
  show = pkgs.writeShellScriptBin "comr-config-show" ''
    #!/usr/bin/env bash
    CONFIG_FILE="${cell.data.configPaths.unified.config}"

    echo "📋 Current Configuration"
    echo "======================="
    ${pkgs.jq}/bin/jq . "$CONFIG_FILE"
  '';

  # Validate config
  validate = pkgs.writeShellScriptBin "comr-config-validate" ''
    #!/usr/bin/env bash
    CONFIG_FILE="${cell.data.configPaths.unified.config}"

    echo "🔍 Validating configuration..."

    # Check config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
      echo "❌ Config file not found: $CONFIG_FILE"
      exit 1
    fi

    # Validate JSON syntax
    if ! ${pkgs.jq}/bin/jq empty "$CONFIG_FILE" 2>/dev/null; then
      echo "❌ Invalid JSON syntax"
      exit 1
    fi

    # Check required fields
    REQUIRED_FIELDS="version activeProfile profiles storage"
    for FIELD in $REQUIRED_FIELDS; do
      if ! ${pkgs.jq}/bin/jq -e ".$FIELD" "$CONFIG_FILE" >/dev/null; then
        echo "❌ Missing required field: $FIELD"
        exit 1
      fi
    done

    # Validate API key formats (if set)
    # ... additional validation logic ...

    echo "✅ Configuration is valid"
  '';

  # Migrate from existing configs
  migrate = pkgs.writeShellScriptBin "comr-config-migrate" ''
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔄 Migrating existing configurations..."

    # Migrate comr servers.json
    COMR_SERVERS="${cell.data.configPaths.comr.servers}"
    if [[ -f "$COMR_SERVERS" ]]; then
      echo "📦 Found comr servers.json"
      # Run migration function
      nix eval --json '.#config.functions.migrateFromComr' --apply "f: f \"$COMR_SERVERS\"" \
        > /tmp/migrated-comr.json
      echo "✅ Migrated comr config"
    fi

    # Migrate Claude Code settings
    CLAUDE_SETTINGS="${cell.data.configPaths.claude-code.settings}"
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
      echo "📦 Found Claude Code settings"
      nix eval --json '.#config.functions.migrateFromClaudeCode' --apply "f: f \"$CLAUDE_SETTINGS\"" \
        > /tmp/migrated-claude.json
      echo "✅ Migrated Claude Code config"
    fi

    # Merge migrations
    echo "🔗 Merging configurations..."
    # ... merge logic ...

    echo "✅ Migration complete"
  '';

  # Cost calculator
  cost-estimate = pkgs.writeShellScriptBin "comr-config-cost-estimate" ''
    #!/usr/bin/env bash
    MODEL="$1"
    INPUT_TOKENS="$2"
    OUTPUT_TOKENS="$3"

    COST=$(nix eval --raw '.#config.functions.estimateCost' --apply "f: f {
      model = \"$MODEL\";
      inputTokens = $INPUT_TOKENS;
      outputTokens = $OUTPUT_TOKENS;
    }")

    echo "💰 Cost Estimate"
    echo "==============="
    echo "Model: $MODEL"
    echo "Input tokens: $INPUT_TOKENS"
    echo "Output tokens: $OUTPUT_TOKENS"
    echo "Total cost: \$$COST"
  '';

  # Cost usage report
  cost-report = pkgs.writeShellScriptBin "comr-config-cost-report" ''
    #!/usr/bin/env bash
    echo "💰 Cost Usage Report"
    echo "==================="
    # Read from telemetry/usage logs
    # ... report generation ...
  '';
}
```

### Phase 4: Nushell Integration (Week 8, Days 1-3)

**Rationale:** Configuration management involves heavy JSON manipulation, table display, and data aggregation - all areas where Nushell excels over bash+jq. Converting key commands to Nushell improves readability, error handling, and user experience.

**Commands to Convert to Nushell:**
- `show` - Display config with beautiful tables and formatting
- `cost-report` - Aggregate cost data from multiple JSON files
- `list-keys` - Show API keys status across providers
- `compare-profiles` - Compare settings between profiles

**Commands to Keep in Bash (with ShellCheck):**
- `init` - File operations (mkdir, writeFile) simpler in bash
- `set-key` - Interactive prompts (read -s for passwords) better in bash
- `get/set` - Simple value operations fine in bash
- `migrate` - External tool orchestration (nix eval) easier in bash

**Important:** All bash scripts MUST use the validated bash writers from `cells/lib`:
```nix
writeBashApp = inputs.cells.lib.functions.writeBashApplication;
includeBashHelpers = inputs.cells.lib.functions.includeBashHelpers;
```

This ensures:
- ShellCheck validation catches bugs (SC2086, SC2046, etc.)
- Runtime checks enforce `set -euo pipefail`
- Temp file cleanup warnings for trap handlers
- Consistent error handling across all bash scripts

**runnables.nix - Nushell Version:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
in {
  # Keep bash for simple operations (using validated writers)
  writeBashApp = inputs.cells.lib.functions.writeBashApplication;
  includeBashHelpers = inputs.cells.lib.functions.includeBashHelpers;

  init = writeBashApp {
    name = "comr-config-init";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      ${includeBashHelpers}
      set -euo pipefail

      CONFIG_DIR="$HOME/.config/comr"
      CONFIG_FILE="$CONFIG_DIR/config.json"

      log info "Initializing comr configuration..."

      ensure_dir "$CONFIG_DIR"

      # Create default config
      cat > "$CONFIG_FILE" <<'EOF'
      ${builtins.toJSON cell.data.defaults}
      EOF

      log info "Configuration initialized at $CONFIG_FILE"
      echo ""
      echo "Next steps:"
      echo "1. Set API keys: export ANTHROPIC_API_KEY=sk-..."
      echo "2. Or use keyring: comr config set-key anthropic"
      echo "3. Configure preferences: comr config set defaultModel claude-3.5-sonnet"
    '';
  };

  set-key = writeBashApp {
    name = "comr-config-set-key";
    runtimeInputs = [ pkgs.age pkgs.libsecret pkgs.jq ];
    text = ''
      ${includeBashHelpers}
      set -euo pipefail

      if [[ $# -lt 1 ]]; then
        log error "Usage: $0 <provider> [storage-method]"
        echo "Storage methods: environment, keyring, age-encrypted"
        exit 1
      fi

      PROVIDER="$1"
      STORAGE="''${2:-environment}"

      log info "Setting API key for $PROVIDER using $STORAGE storage..."

      case "$STORAGE" in
        environment)
          local env_var
          env_var=$(echo "$PROVIDER" | tr '[:lower:]' '[:upper:]')_API_KEY
          echo "Add to your shell profile:"
          echo "  export $env_var=your-key-here"
          ;;

        keyring)
          if ! has_command secret-tool; then
            log error "secret-tool not found. Install libsecret-tools"
            exit 1
          fi

          local api_key
          api_key=$(prompt_password "Enter API key for $PROVIDER")

          if [[ -z "$api_key" ]]; then
            log error "API key cannot be empty"
            exit 1
          fi

          echo -n "$api_key" | secret-tool store \
            --label="comr $PROVIDER API Key" \
            service comr \
            provider "$PROVIDER"

          log info "API key stored in system keyring"
          ;;

        age-encrypted)
          if ! has_command age; then
            log error "age not found. Install age encryption tool"
            exit 1
          fi

          local api_key
          api_key=$(prompt_password "Enter API key for $PROVIDER")

          if [[ -z "$api_key" ]]; then
            log error "API key cannot be empty"
            exit 1
          fi

          local secrets_file="$HOME/.config/comr/secrets.age"
          local age_key_file="$HOME/.config/comr/age-key.txt"

          # Generate age key if not exists
          if [[ ! -f "$age_key_file" ]]; then
            age-keygen -o "$age_key_file"
            chmod 600 "$age_key_file"
            log warning "Age key generated. BACKUP THIS FILE: $age_key_file"
          fi

          # Read existing secrets or create new
          local secrets="{}"
          if [[ -f "$secrets_file" ]]; then
            secrets=$(age -d -i "$age_key_file" "$secrets_file")
          fi

          # Update secrets
          local updated
          updated=$(echo "$secrets" | jq ".apiKeys.\"$PROVIDER\" = \"$api_key\"")

          # Encrypt and save
          local temp
          temp=$(make_temp)
          echo "$updated" | age -e -i "$age_key_file" -o "$temp"
          mv "$temp" "$secrets_file"
          chmod 600 "$secrets_file"

          log info "API key encrypted and stored"
          ;;

        *)
          log error "Unknown storage method: $STORAGE"
          echo "Valid methods: environment, keyring, age-encrypted"
          exit 1
          ;;
      esac
    '';
  };

  # Convert to Nushell for data operations
  show = writeNuApp {
    name = "comr-config-show";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [] {
        let config_file = "~/.config/comr/config.json"

        log "info" "Loading configuration"

        let config = (safe-read-json $config_file {
          error: "Config file not found. Run: comr config init"
        })

        if "error" in $config {
          print $config.error
          exit 1
        }

        # Display configuration with rich formatting
        print "📋 Configuration Overview"
        print "========================="
        print ""

        # Active profile
        print $"Active Profile: ($config.activeProfile)"
        print ""

        # Profile details
        let profile = $config.profiles | get ($config.activeProfile)

        print "User Preferences:"
        $profile.preferences
          | transpose setting value
          | each { |row| print $"  ($row.setting): ($row.value)" }
        print ""

        # Cost limits
        print "Cost Limits:"
        $profile.limits
          | transpose limit value
          | where value != null
          | each { |row| print $"  ($row.limit): ($row.value)" }
        print ""

        # Rate limits
        print "Rate Limits:"
        $profile.rateLimits
          | transpose limit value
          | where value != null
          | each { |row| print $"  ($row.limit): ($row.value)" }
        print ""

        # API Keys Status
        print "API Keys Status:"
        list-api-keys-status
      }

      # Helper: Check API key status
      def list-api-keys-status [] {
        let providers = [
          "anthropic"
          "google"
          "openai"
          "openrouter"
          "github"
          "slack"
        ]

        $providers
          | each { |provider|
              let env_var = ($provider | str upcase | $in + "_API_KEY")
              let is_set = (($env | get -i $env_var) != null)

              {
                provider: $provider
                status: (if $is_set { "✅ Set" } else { "❌ Not Set" })
              }
            }
          | table
      }
    '';
  };

  # Cost report with Nushell
  cost-report = writeNuApp {
    name = "comr-config-cost-report";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --period: string = "day"  # day, week, month
      ] {
        print "💰 Cost Usage Report"
        print "==================="
        print ""

        # Read cost data from telemetry logs
        let logs_dir = "~/.config/comr/logs"
        let metrics_dir = "~/.cache/comr/metrics"

        # Parse cost entries from logs
        let costs = (parse-cost-logs $logs_dir $metrics_dir)

        if ($costs | length) == 0 {
          print "No cost data available yet"
          return
        }

        # Filter by period
        let filtered = (filter-by-period $costs $period)

        # Aggregate by model
        print $"Costs by Model (last ($period)):"
        $filtered
          | group-by model
          | transpose model entries
          | insert total_cost { |row|
              $row.entries | get cost | math sum
            }
          | insert calls { |row|
              $row.entries | length
            }
          | select model calls total_cost
          | sort-by -r total_cost
          | table
        print ""

        # Aggregate by workspace
        print $"Costs by Workspace:"
        $filtered
          | group-by workspace
          | transpose workspace entries
          | insert total_cost { |row|
              $row.entries | get cost | math sum
            }
          | select workspace total_cost
          | sort-by -r total_cost
          | table
        print ""

        # Overall stats
        let total = ($filtered | get cost | math sum)
        let avg = ($filtered | get cost | math avg)
        let count = ($filtered | length)

        print "Overall Statistics:"
        print $"  Total Spend: \$($total | into string)"
        print $"  Average per Request: \$($avg | into string)"
        print $"  Total Requests: ($count)"
        print ""

        # Check against limits
        check-cost-limits $total $period
      }

      # Parse cost logs
      def parse-cost-logs [logs_dir: string, metrics_dir: string] {
        # Look for cost metrics in metrics directory
        let metrics_files = (ls ($metrics_dir + "/*.jsonl") | get name)

        $metrics_files
          | each { |file|
              open $file
                | lines
                | each { from json }
                | where metric == "llm.request_cost"
            }
          | flatten
          | each { |entry|
              {
                timestamp: $entry.timestamp
                model: ($entry.labels.model? | default "unknown")
                workspace: ($entry.labels.workspace? | default "unknown")
                cost: $entry.value
              }
            }
      }

      # Filter by time period
      def filter-by-period [costs: list, period: string] {
        let now = (date now)

        let cutoff = match $period {
          "day" => { $now - 1day }
          "week" => { $now - 7day }
          "month" => { $now - 30day }
          _ => { $now - 1day }
        }

        $costs | where ($it.timestamp | into datetime) > $cutoff
      }

      # Check cost limits
      def check-cost-limits [total: float, period: string] {
        let config = (safe-read-json "~/.config/comr/config.json" {})

        if "error" in $config {
          return
        }

        let profile = $config.profiles | get ($config.activeProfile)
        let limits = $profile.limits

        let limit = match $period {
          "day" => { $limits.maxCostPerDay }
          "month" => { $limits.maxCostPerMonth }
          _ => { null }
        }

        if $limit == null {
          return
        }

        let percent = ($total / $limit) * 100
        let warn_threshold = $limits.warnThresholdPercent

        if $percent > 100 {
          print $"⚠️  LIMIT EXCEEDED: \$($total) exceeds ($period)ly limit of \$($limit)"
        } else if $percent > $warn_threshold {
          print $"⚠️  WARNING: At ($percent | math round)% of ($period)ly limit (\$($total) / \$($limit))"
        } else {
          print $"✅ Within limits: ($percent | math round)% of ($period)ly limit"
        }
      }
    '';
  };

  # List API keys status
  list-keys = writeNuApp {
    name = "comr-config-list-keys";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [] {
        print "🔑 API Keys Status"
        print "================="
        print ""

        let providers = [
          {name: "anthropic", var: "ANTHROPIC_API_KEY", format: "sk-ant-*"}
          {name: "google", var: "GEMINI_API_KEY", format: "*"}
          {name: "openai", var: "OPENAI_API_KEY", format: "sk-*"}
          {name: "openrouter", var: "OPENROUTER_API_KEY", format: "sk-or-*"}
          {name: "github", var: "GITHUB_TOKEN", format: "gh[ps]_*"}
          {name: "slack", var: "SLACK_TOKEN", format: "xoxb-*"}
          {name: "stripe", var: "STRIPE_API_KEY", format: "sk_*"}
          {name: "huggingface", var: "HF_TOKEN", format: "hf_*"}
        ]

        $providers
          | each { |prov|
              let value = ($env | get -i $prov.var)
              let is_set = ($value != null)

              {
                provider: $prov.name
                status: (if $is_set { "✅ Set" } else { "❌ Not Set" })
                format_expected: $prov.format
                format_valid: (if $is_set {
                  validate-format $value $prov.format
                } else {
                  "N/A"
                })
              }
            }
          | table
      }

      # Validate key format
      def validate-format [key: string, pattern: string] {
        # Simple pattern matching (would be more sophisticated in production)
        if ($key | str starts-with "sk-") and ($pattern | str contains "sk-") {
          "✅ Valid"
        } else if $pattern == "*" {
          "✅ Valid"
        } else {
          "⚠️  Check format"
        }
      }
    '';
  };

  # Compare profiles
  compare-profiles = writeNuApp {
    name = "comr-config-compare-profiles";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [profile1: string, profile2: string] {
        let config = (safe-read-json "~/.config/comr/config.json" {})

        if "error" in $config {
          print "Config file not found"
          exit 1
        }

        print $"🔄 Comparing Profiles: ($profile1) vs ($profile2)"
        print "=" * 50
        print ""

        let p1 = $config.profiles | get $profile1
        let p2 = $config.profiles | get $profile2

        # Compare preferences
        print "User Preferences:"
        compare-section $p1.preferences $p2.preferences $profile1 $profile2
        print ""

        # Compare limits
        print "Cost Limits:"
        compare-section $p1.limits $p2.limits $profile1 $profile2
        print ""

        # Compare rate limits
        print "Rate Limits:"
        compare-section $p1.rateLimits $p2.rateLimits $profile1 $profile2
      }

      # Compare two configuration sections
      def compare-section [s1: record, s2: record, name1: string, name2: string] {
        let keys = ($s1 | transpose key value | get key)

        $keys
          | each { |key|
              let v1 = ($s1 | get $key)
              let v2 = ($s2 | get $key)

              {
                setting: $key
                ($name1): $v1
                ($name2): $v2
                different: ($v1 != $v2)
              }
            }
          | table
      }
    '';
  };

  # Keep bash for other commands
  get = pkgs.writeShellScriptBin "comr-config-get" ''
    # ... same as before ...
  '';

  set = pkgs.writeShellScriptBin "comr-config-set" ''
    # ... same as before ...
  '';

  switch-profile = pkgs.writeShellScriptBin "comr-config-switch-profile" ''
    # ... same as before ...
  '';

  validate = pkgs.writeShellScriptBin "comr-config-validate" ''
    # ... same as before ...
  '';

  migrate = pkgs.writeShellScriptBin "comr-config-migrate" ''
    # ... same as before ...
  '';

  cost-estimate = pkgs.writeShellScriptBin "comr-config-cost-estimate" ''
    # ... same as before ...
  '';
}
```

**Benefits of Nushell for Config:**

1. **Rich Table Display**: `show` command presents config as formatted tables instead of raw JSON
2. **Data Aggregation**: `cost-report` groups and aggregates without complex jq pipelines
3. **Type Safety**: Nushell catches type errors (null checks, etc.)
4. **Error Handling**: try/catch instead of bash's if-statements
5. **Readability**: Data transformations are pipelines, not nested command substitutions

**Example Output Comparison:**

**Bash (raw JSON):**
```bash
$ comr config show
{
  "version": "1.0.0",
  "activeProfile": "dev",
  "profiles": {
    "dev": {
      ...
    }
  }
}
```

**Nushell (formatted tables):**
```bash
$ comr config show
📋 Configuration Overview
=========================

Active Profile: dev

User Preferences:
  defaultModel: gemini-2.0-flash-lite
  temperature: 0.7
  maxTokens: 4096

Cost Limits:
  maxCostPerDay: 5.0
  maxCostPerMonth: 100.0

API Keys Status:
╭───────────┬──────────╮
│ provider  │ status   │
├───────────┼──────────┤
│ anthropic │ ✅ Set   │
│ google    │ ✅ Set   │
│ openai    │ ❌ Not Set│
╰───────────┴──────────╯
```

**When to Use Each:**

**Use Nushell:**
- ✅ Data display (`show`, `list-keys`, `compare-profiles`)
- ✅ Aggregation (`cost-report`)
- ✅ Complex filtering/grouping
- ✅ Table formatting

**Keep Bash:**
- ✅ Simple value get/set
- ✅ Interactive prompts (`read -s`)
- ✅ File operations (mkdir, cp)
- ✅ External tool orchestration (age, secret-tool)

## Dependencies

- Inputs: `nixpkgs`, `inputs.cells.lib` (for Nushell writers)
- External: `age`, `libsecret` (for keyring), `jq`, `nushell`
- Consumes: `cells/lib` (Nushell writers and helpers)
- Produces for: ALL cells (llm, agents, workspaces, orchestrators, routing, mcp)

## Success Criteria

- [ ] Configuration schema defined with Nix types
- [ ] API key management supports environment, keyring, age-encrypted
- [ ] Environment profiles (dev/staging/prod) work
- [ ] User preferences configurable
- [ ] Cost caps and rate limits enforced
- [ ] Migration from existing configs functional
- [ ] Configuration validation works
- [ ] CLI tools for config management provided
- [ ] **Nushell commands (show, cost-report, list-keys, compare-profiles) functional**
- [ ] **Rich table formatting working**
- [ ] **Cost aggregation and reporting accurate**
- [ ] Documentation complete
- [ ] All cells can consume config API
