{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # Get API key from environment
  getFromEnv = provider:
    let
      envVar = cell.data.envVarMappings.${provider} or null;
    in
      if envVar == null
      then throw "Unknown provider: ${provider}"
      else if builtins.isList envVar
      then builtins.map (v: builtins.getEnv v) envVar
      else builtins.getEnv envVar;

  # Get API key from system keyring (runtime operation)
  getFromKeyring = provider:
    pkgs.runCommand "get-keyring-${provider}" {
      buildInputs = [ pkgs.libsecret ];
    } ''
      secret-tool lookup service comr provider ${provider} > $out
    '';

  # Get API key from age-encrypted file (runtime operation)
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
  checkRequiredKeys = cellName:
    let
      requirements = cell.data.apiKeyRequirements.${cellName} or {};
      missing = builtins.filter (provider:
        let
          key = getFromEnv provider;
        in key == "" || key == null
      ) (builtins.attrNames (builtins.filter (k: k.required or false) requirements));
    in
      if missing != []
      then throw "Missing required API keys for ${cellName}: ${builtins.concatStringsSep ", " missing}"
      else true;

  # Update config file (runtime operation)
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

  # Migrate from existing comr config
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

  # Migrate from Claude Code settings
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
      profile = cell.lib.loadProfile cell.data.defaults.activeProfile;
      limit = profile.limits.${limitType};
      warnThreshold = profile.limits.warnThresholdPercent;
    in
      if limit == null
      then { ok = true; warning = false; }
      else if cost > limit
      then { ok = false; warning = false; error = "Cost ${builtins.toString cost} exceeds limit ${builtins.toString limit}"; }
      else if cost > (limit * warnThreshold / 100.0)
      then { ok = true; warning = true; message = "Cost ${builtins.toString cost} is ${builtins.toString (cost / limit * 100)}% of limit"; }
      else { ok = true; warning = false; };

  # Validate configuration
  validateConfig = config:
    let
      # Type check using Nix type system
      checked = pkgs.lib.evalModules {
        modules = [
          { options = cell.types.configType.getSubOptions []; }
          { config = config; }
        ];
      };
    in
      if checked.config == config
      then config
      else throw "Config validation failed";

  # Generate default config file
  generateDefaultConfig = pkgs.writeText "default-config.json"
    (builtins.toJSON cell.data.defaults);
}
