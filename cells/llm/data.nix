{inputs, cell}: rec {
  # Model capabilities and costs
  models = {
    # Anthropic Models (API-based)
    "claude-3.5-sonnet" = {
      type = "api";
      provider = "anthropic";
      apiEnv = "ANTHROPIC_API_KEY";
      cost = {
        input = 3.00;   # per million tokens
        output = 15.00;
      };
      context = 200000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["claude" "sonnet"];
    };

    "claude-3.5-haiku" = {
      type = "api";
      provider = "anthropic";
      apiEnv = "ANTHROPIC_API_KEY";
      cost = {
        input = 0.80;
        output = 4.00;
      };
      context = 200000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["haiku"];
    };

    # Google Models (API-based)
    "gemini-2.0-flash" = {
      type = "api";
      provider = "google";
      apiEnv = "GEMINI_API_KEY";
      cost = {
        input = 0.075;
        output = 0.30;
      };
      context = 1000000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gemini" "flash"];
    };

    "gemini-2.0-flash-lite" = {
      type = "api";
      provider = "google";
      apiEnv = "GEMINI_API_KEY";
      cost = {
        input = 0.00;  # Free tier
        output = 0.00;
      };
      context = 1000000;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["gemini-lite" "flash-lite"];
    };

    "gemini-2.5-pro" = {
      type = "api";
      provider = "google";
      apiEnv = "GEMINI_API_KEY";
      cost = {
        input = 1.25;
        output = 5.00;
      };
      context = 2000000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gemini-pro"];
    };

    # OpenAI Models (API-based, via OpenRouter or direct)
    "gpt-4o" = {
      type = "api";
      provider = "openai";
      apiEnv = "OPENAI_API_KEY";
      cost = {
        input = 2.50;
        output = 10.00;
      };
      context = 128000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gpt4" "openai"];
    };

    "gpt-4o-mini" = {
      type = "api";
      provider = "openai";
      apiEnv = "OPENAI_API_KEY";
      cost = {
        input = 0.15;
        output = 0.60;
      };
      context = 128000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gpt4-mini"];
    };

    # Qwen Models (API-based)
    "qwen-2.5-coder" = {
      type = "api";
      provider = "qwen";
      apiEnv = "DASHSCOPE_API_KEY";
      cost = {
        input = 0.00;  # Free tier available
        output = 0.00;
      };
      context = 131072;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["qwen" "coder"];
    };

    # Local models via Ollama (API-based)
    "llama-3.2" = {
      type = "api";
      provider = "ollama";
      apiEnv = null;
      cost = { input = 0.00; output = 0.00; };
      context = 128000;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["llama"];
      local = true;
    };

    "deepseek-coder-v2" = {
      type = "api";
      provider = "ollama";
      apiEnv = null;
      cost = { input = 0.00; output = 0.00; };
      context = 128000;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["deepseek"];
      local = true;
    };

    # CLI-based models (integrated agent interfaces)
    "claude-code-cli" = {
      type = "cli";
      provider = "anthropic";
      apiEnv = "ANTHROPIC_API_KEY";
      cliCommand = "claude";
      cliArgs = ["-p" "--output-format" "json"];
      cliModelFlag = "--model";
      cliModelValue = "claude-3.5-sonnet";
      cost = {
        input = 3.00;   # Same as claude-3.5-sonnet
        output = 15.00;
      };
      context = 200000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["claude-cli" "cc"];
      # CLI-specific metadata
      cliPath = "claude";  # Assumes in PATH or from cells.agents.claude-code.packages
      apiEquivalent = "claude-3.5-sonnet";
    };

    "gemini-cli" = {
      type = "cli";
      provider = "google";
      apiEnv = "GEMINI_API_KEY";
      cliCommand = "gemini";
      cliArgs = ["chat"];
      cost = {
        input = 0.075;  # Same as gemini-2.0-flash
        output = 0.30;
      };
      context = 1000000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gcli"];
      cliPath = "gemini";
      apiEquivalent = "gemini-2.0-flash";
    };

    "qwen-cli" = {
      type = "cli";
      provider = "qwen";
      apiEnv = "DASHSCOPE_API_KEY";
      cliCommand = "qwen";
      cliArgs = [];
      cost = {
        input = 0.00;  # Free tier
        output = 0.00;
      };
      context = 131072;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["qc"];
      cliPath = "qwen";
      apiEquivalent = "qwen-2.5-coder";
    };
  };

  # LLM plugin registry for llm.datasette.io
  plugins = {
    # Model providers
    "llm-claude-3" = {
      type = "model-provider";
      package = "llm-claude-3";
      models = ["claude-3.5-sonnet" "claude-3.5-haiku" "claude-3-opus"];
      required = true;  # Essential plugin
    };

    "llm-gemini" = {
      type = "model-provider";
      package = "llm-gemini";
      models = ["gemini-2.0-flash" "gemini-2.5-pro" "gemini-2.0-flash-lite"];
      required = true;  # Essential plugin
    };

    "llm-ollama" = {
      type = "model-provider";
      package = "llm-ollama";
      models = ["llama-3.2" "mistral" "phi" "deepseek-coder-v2"];
      required = false;  # Optional for local models
    };

    # Utility plugins
    "llm-cmd" = {
      type = "tool";
      package = "llm-cmd";
      description = "Generate shell commands from natural language";
      required = false;
    };

    "llm-python" = {
      type = "tool";
      package = "llm-python";
      description = "Execute Python code in LLM conversations";
      required = false;
    };

    # Embeddings
    "llm-sentence-transformers" = {
      type = "embedding";
      package = "llm-sentence-transformers";
      models = ["all-MiniLM-L6-v2" "all-mpnet-base-v2"];
      required = false;
    };
  };

  # Provider-specific configuration
  providers = {
    anthropic = {
      name = "Anthropic";
      apiKeyEnv = "ANTHROPIC_API_KEY";
      endpoint = "https://api.anthropic.com";
      rateLimits = {
        requestsPerMinute = 50;
        tokensPerMinute = 100000;
      };
    };

    google = {
      name = "Google";
      apiKeyEnv = "GEMINI_API_KEY";
      endpoint = "https://generativelanguage.googleapis.com";
      rateLimits = {
        requestsPerMinute = 60;
        tokensPerMinute = null;  # Generous free tier
      };
    };

    openai = {
      name = "OpenAI";
      apiKeyEnv = "OPENAI_API_KEY";
      endpoint = "https://api.openai.com";
      rateLimits = {
        requestsPerMinute = 500;  # Tier-dependent
        tokensPerMinute = 150000;
      };
    };

    qwen = {
      name = "Qwen/Dashscope";
      apiKeyEnv = "DASHSCOPE_API_KEY";
      endpoint = "https://dashscope.aliyuncs.com";
      rateLimits = {
        requestsPerMinute = 60;
        tokensPerMinute = null;
      };
    };

    ollama = {
      name = "Ollama";
      apiKeyEnv = null;
      endpoint = "http://localhost:11434";
      rateLimits = {
        requestsPerMinute = null;  # Local, no limits
        tokensPerMinute = null;
      };
    };
  };

  # Cost calculator
  calculateCost = model: inputTokens: outputTokens:
    let
      modelData = models.${model};
      inputCost = (inputTokens / 1000000.0) * modelData.cost.input;
      outputCost = (outputTokens / 1000000.0) * modelData.cost.output;
    in inputCost + outputCost;

  # Model selection helpers
  modelsByProvider = provider:
    builtins.filter (name: models.${name}.provider == provider)
      (builtins.attrNames models);

  modelsByCapability = capability:
    builtins.filter (name:
      if capability == "vision" then models.${name}.vision
      else if capability == "streaming" then models.${name}.streaming
      else if capability == "tools" then models.${name}.tools
      else if capability == "local" then models.${name}.local or false
      else false
    ) (builtins.attrNames models);

  # Default models per use case
  defaults = {
    chat = "gemini-2.0-flash-lite";  # Free, fast for general chat
    reasoning = "claude-3.5-sonnet";  # Best for complex reasoning
    code = "claude-3.5-sonnet";  # Best for code generation
    vision = "gemini-2.5-pro";  # Best vision capabilities
    cheap = "gemini-2.0-flash-lite";  # Free tier
    fast = "claude-3.5-haiku";  # Lowest latency
    local = "llama-3.2";  # Privacy-first
  };
}
