{inputs, cell}: let
  lib = inputs.nixpkgs.lib;
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
          "dashscope"
          "brave"
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

  # Model type
  modelType = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.enum ["anthropic" "google" "openai" "openrouter" "dashscope"];
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
