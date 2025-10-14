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

    "gemini-2.5-pro" = {
      provider = "google";
      name = "gemini-2.5-pro";
      context = 2097152;  # 2M
      costPer1kTokens = { input = 0.00125; output = 0.005; };
      capabilities = ["chat" "function-calling" "vision" "code-generation" "reasoning"];
    };

    # OpenAI (via OpenRouter)
    "gpt-4" = {
      provider = "openrouter";
      name = "openai/gpt-4";
      context = 8192;
      costPer1kTokens = { input = 0.03; output = 0.06; };
      capabilities = ["chat" "function-calling" "code-generation"];
    };

    "gpt-4-turbo" = {
      provider = "openrouter";
      name = "openai/gpt-4-turbo";
      context = 128000;
      costPer1kTokens = { input = 0.01; output = 0.03; };
      capabilities = ["chat" "function-calling" "vision" "code-generation"];
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

  # Environment variable mappings
  envVarMappings = {
    anthropic = "ANTHROPIC_API_KEY";
    google = "GEMINI_API_KEY";
    openai = "OPENAI_API_KEY";
    openrouter = "OPENROUTER_API_KEY";
    dashscope = "DASHSCOPE_API_KEY";
    huggingface = "HF_TOKEN";
    github = "GITHUB_TOKEN";
    slack = "SLACK_TOKEN";
    stripe = "STRIPE_API_KEY";
    brave = "BRAVE_API_KEY";
    aws = ["AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY"];
  };
}
